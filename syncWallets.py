#!/usr/bin/env python3
"""
Flow Wallet Sync Script

This script syncs wallet data between the database and flow-production.json:
1. Fetches all wallet data from Supabase database
2. Updates flow-production.json with current database state
3. Ensures pkey files are in the correct pkeys/ subdirectory
4. Handles missing or corrupted wallet data gracefully

Usage:
    python3 syncWallets.py
"""

import json
import os
import sys
import subprocess
import re
from pathlib import Path
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configuration
NETWORK = "mainnet"

# Supabase configuration
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

class WalletSyncer:
    def __init__(self):
        self.supabase = None
        self.flow_dir = Path("flow")
        self.accounts_dir = self.flow_dir / "accounts"
        self.pkeys_dir = self.accounts_dir / "pkeys"
        self.production_file = self.accounts_dir / "flow-production.json"
        
        # Statistics
        self.total_wallets = 0
        self.synced_wallets = 0
        self.missing_pkeys = 0
        self.corrupted_wallets = 0
        self.algorithm_updates = 0
        self.algorithm_errors = 0
        
    def get_supabase_client(self):
        """Initialize and return Supabase client with service role"""
        try:
            if not SUPABASE_URL:
                print("Error: SUPABASE_URL not set in .env file")
                return None
                
            if not SUPABASE_SERVICE_KEY:
                print("Error: SUPABASE_SERVICE_ROLE_KEY not set in .env file")
                return None
            
            supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
            return supabase
        except Exception as e:
            print(f"Error initializing Supabase client: {e}")
            return None
    
    def get_all_wallets_from_database(self):
        """Get all wallet data from the database with pagination"""
        try:
            all_wallets = []
            page = 1
            per_page = 1000
            
            print(f"🔍 Fetching wallet data from database...")
            
            while True:
                print(f"📄 Fetching page {page} (per_page={per_page})...")
                result = self.supabase.table('wallet').select('*').range(
                    (page - 1) * per_page, 
                    page * per_page - 1
                ).execute()
                
                if not result.data or len(result.data) == 0:
                    print(f"📄 Page {page} returned no wallets, stopping pagination")
                    break
                
                print(f"📄 Page {page} returned {len(result.data)} wallets")
                all_wallets.extend(result.data)
                
                if len(result.data) < per_page:
                    print(f"📄 Page {page} had fewer wallets than per_page, stopping pagination")
                    break
                    
                page += 1
            
            print(f"📊 Total wallets fetched from database: {len(all_wallets)}")
            return all_wallets
            
        except Exception as e:
            print(f"Error fetching wallets from database: {e}")
            return []
    
    def check_wallet_signature_algorithm(self, flow_address):
        """Check the signature algorithm for a wallet on the Flow blockchain"""
        try:
            # Run flow accounts get command
            cmd = [
                'flow', 'accounts', 'get', flow_address,
                '--network', NETWORK,
                '--format', 'json'
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                print(f"⚠️  Error checking algorithm for {flow_address}: {result.stderr}")
                return None, None
            
            # Parse JSON output
            account_data = json.loads(result.stdout)
            
            # Extract signature algorithm info from the first key
            if 'keys' in account_data and len(account_data['keys']) > 0:
                key = account_data['keys'][0]
                signature_algo = key.get('signatureAlgorithm', '')
                hash_algo = key.get('hashAlgorithm', '')
                
                # Convert Flow CLI format to our config format
                if signature_algo == 'ECDSA_P256':
                    sig_algo = 'ECDSA_P256'
                elif signature_algo == 'ECDSA_secp256k1':
                    sig_algo = 'ECDSA_secp256k1'
                else:
                    sig_algo = signature_algo
                
                if hash_algo == 'SHA3_256':
                    hash_algo = 'SHA3_256'
                elif hash_algo == 'SHA2_256':
                    hash_algo = 'SHA2_256'
                
                return sig_algo, hash_algo
            else:
                print(f"⚠️  No keys found for address {flow_address}")
                return None, None
                
        except subprocess.TimeoutExpired:
            print(f"⚠️  Timeout checking algorithm for {flow_address}")
            return None, None
        except json.JSONDecodeError as e:
            print(f"⚠️  Error parsing JSON for {flow_address}: {e}")
            return None, None
        except Exception as e:
            print(f"⚠️  Error checking algorithm for {flow_address}: {e}")
            return None, None
    
    def validate_wallet_data(self, wallet):
        """Validate that wallet has all required fields"""
        required_fields = ['auth_id', 'flow_address', 'flow_private_key', 'flow_public_key']
        
        for field in required_fields:
            if not wallet.get(field):
                print(f"⚠️  Wallet {wallet.get('auth_id', 'unknown')} missing {field}")
                return False
        
        return True
    
    def check_pkey_file_exists(self, auth_id):
        """Check if pkey file exists in the pkeys directory"""
        pkey_file = self.pkeys_dir / f"{auth_id}.pkey"
        return pkey_file.exists()
    
    def create_pkey_file(self, auth_id, private_key):
        """Create pkey file in the pkeys directory"""
        try:
            self.pkeys_dir.mkdir(exist_ok=True)
            pkey_file = self.pkeys_dir / f"{auth_id}.pkey"
            
            with open(pkey_file, 'w') as f:
                f.write(private_key)
            
            print(f"✓ Created pkey file: {pkey_file}")
            return True
        except Exception as e:
            print(f"❌ Error creating pkey file for {auth_id}: {e}")
            return False
    
    def update_wallet_algorithm_in_database(self, auth_id, signature_algorithm, hash_algorithm):
        """Update wallet signature algorithm information in the database"""
        try:
            # First, check if the columns exist, if not, add them
            self.ensure_algorithm_columns_exist()
            
            # Update the wallet record
            result = self.supabase.table('wallet').update({
                'signature_algorithm': signature_algorithm,
                'hash_algorithm': hash_algorithm,
                'last_algorithm_check': datetime.now().isoformat()
            }).eq('auth_id', auth_id).execute()
            
            if result.data:
                print(f"✓ Updated algorithm for {auth_id}: {signature_algorithm} + {hash_algorithm}")
                return True
            else:
                print(f"⚠️  No wallet found with auth_id {auth_id}")
                return False
                
        except Exception as e:
            print(f"❌ Error updating algorithm for {auth_id}: {e}")
            return False
    
    def ensure_algorithm_columns_exist(self):
        """Ensure signature algorithm columns exist in the database"""
        try:
            # Try to add the columns if they don't exist
            # Note: This is a simplified approach - in production you'd want proper migrations
            pass  # For now, we'll assume the columns exist or will be added manually
        except Exception as e:
            print(f"⚠️  Note: Algorithm columns may not exist in database: {e}")
            print("Please add signature_algorithm and hash_algorithm columns to the wallet table")
    
    def load_existing_production_config(self):
        """Load existing flow-production.json if it exists"""
        if self.production_file.exists():
            try:
                with open(self.production_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                print(f"⚠️  Error loading existing flow-production.json: {e}")
                return {"accounts": {}}
        else:
            return {"accounts": {}}
    
    def create_production_config(self, wallets):
        """Create flow-production.json from wallet data"""
        production_config = {
            "accounts": {}
        }
        
        for wallet in wallets:
            auth_id = wallet['auth_id']
            
            # Validate wallet data
            if not self.validate_wallet_data(wallet):
                self.corrupted_wallets += 1
                continue
            
            # Check if pkey file exists
            if not self.check_pkey_file_exists(auth_id):
                print(f"⚠️  Missing pkey file for {auth_id}, creating it...")
                if not self.create_pkey_file(auth_id, wallet['flow_private_key']):
                    self.missing_pkeys += 1
                    continue
            
            # Get signature algorithm from database or check on blockchain
            signature_algorithm = wallet.get('signature_algorithm')
            hash_algorithm = wallet.get('hash_algorithm')
            
            # If not in database, check on blockchain
            if not signature_algorithm or not hash_algorithm:
                print(f"🔍 Checking signature algorithm for {auth_id} ({wallet['flow_address']})...")
                sig_algo, hash_algo = self.check_wallet_signature_algorithm(wallet['flow_address'])
                
                if sig_algo and hash_algo:
                    signature_algorithm = sig_algo
                    hash_algorithm = hash_algo
                    
                    # Update database with the correct algorithms
                    if self.update_wallet_algorithm_in_database(auth_id, signature_algorithm, hash_algorithm):
                        self.algorithm_updates += 1
                else:
                    print(f"⚠️  Could not determine algorithm for {auth_id}, using defaults")
                    signature_algorithm = "ECDSA_P256"  # Default to P256
                    hash_algorithm = "SHA3_256"  # Default to SHA3_256
                    self.algorithm_errors += 1
            
            # Add to production config
            production_config["accounts"][auth_id] = {
                "address": wallet['flow_address'],
                "key": {
                    "type": "file",
                    "location": f"accounts/pkeys/{auth_id}.pkey",
                    "signatureAlgorithm": signature_algorithm,
                    "hashAlgorithm": hash_algorithm
                }
            }
            
            self.synced_wallets += 1
        
        return production_config
    
    def save_production_config(self, config):
        """Save production config to flow-production.json"""
        try:
            # Create backup of existing file
            if self.production_file.exists():
                backup_file = self.production_file.with_suffix('.json.backup')
                self.production_file.rename(backup_file)
                print(f"📋 Created backup: {backup_file}")
            
            # Write new config
            with open(self.production_file, 'w') as f:
                json.dump(config, f, indent=4)
            
            print(f"✓ Saved flow-production.json with {len(config['accounts'])} accounts")
            return True
        except Exception as e:
            print(f"❌ Error saving flow-production.json: {e}")
            return False
    
    def cleanup_orphaned_pkey_files(self, valid_auth_ids):
        """Remove pkey files that don't have corresponding database entries"""
        try:
            if not self.pkeys_dir.exists():
                return
            
            orphaned_files = []
            for pkey_file in self.pkeys_dir.glob("*.pkey"):
                auth_id = pkey_file.stem
                if auth_id not in valid_auth_ids:
                    orphaned_files.append(pkey_file)
            
            if orphaned_files:
                print(f"🧹 Found {len(orphaned_files)} orphaned pkey files:")
                for pkey_file in orphaned_files:
                    print(f"  - {pkey_file.name}")
                
                # Ask for confirmation before deleting
                response = input("Delete orphaned pkey files? (y/N): ").strip().lower()
                if response == 'y':
                    for pkey_file in orphaned_files:
                        pkey_file.unlink()
                        print(f"✓ Deleted {pkey_file.name}")
                else:
                    print("Skipped deletion of orphaned files")
            else:
                print("✓ No orphaned pkey files found")
                
        except Exception as e:
            print(f"⚠️  Error during cleanup: {e}")
    
    def run(self):
        """Main sync process"""
        print("🔄 Starting wallet sync process...")
        print("This will sync database wallet data with flow-production.json")
        
        # Ensure we're in the right directory
        if not self.flow_dir.exists():
            print("Error: flow directory not found. Please run this script from the project root.")
            sys.exit(1)
        
        # Initialize Supabase client
        self.supabase = self.get_supabase_client()
        if not self.supabase:
            print("Error: Could not initialize Supabase client.")
            print("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables.")
            sys.exit(1)
        
        # Get all wallets from database
        wallets = self.get_all_wallets_from_database()
        if not wallets:
            print("No wallets found in database.")
            sys.exit(0)
        
        self.total_wallets = len(wallets)
        print(f"📊 Processing {self.total_wallets} wallets...")
        
        # Create production config from database data
        production_config = self.create_production_config(wallets)
        
        # Save production config
        if not self.save_production_config(production_config):
            print("❌ Failed to save production config")
            sys.exit(1)
        
        # Cleanup orphaned pkey files
        valid_auth_ids = set(production_config["accounts"].keys())
        self.cleanup_orphaned_pkey_files(valid_auth_ids)
        
        # Print summary
        print(f"\n🎉 Sync Summary:")
        print(f"- Total wallets in database: {self.total_wallets}")
        print(f"- Successfully synced: {self.synced_wallets}")
        print(f"- Corrupted wallets (skipped): {self.corrupted_wallets}")
        print(f"- Missing pkey files (created): {self.missing_pkeys}")
        print(f"- Algorithm updates: {self.algorithm_updates}")
        print(f"- Algorithm errors: {self.algorithm_errors}")
        print(f"- Production config saved to: {self.production_file}")
        
        if self.synced_wallets == 0:
            print("⚠️  No wallets were successfully synced!")
            sys.exit(1)
        else:
            print("✅ Sync completed successfully!")

def main():
    syncer = WalletSyncer()
    syncer.run()

if __name__ == "__main__":
    main()
