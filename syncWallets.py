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
import re
from pathlib import Path
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from flowWrapper import FlowWrapper, FlowConfig, FlowNetwork, FlowResult

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
        
        # Initialize Flow wrapper
        self.flow_wrapper = FlowWrapper(FlowConfig(
            network=FlowNetwork.MAINNET,
            flow_dir=self.flow_dir,
            timeout=60,
            max_retries=3,
            rate_limit_delay=0.2,
            json_output=True
        ))
        
        # Statistics (thread-safe)
        self.total_wallets = 0
        self.synced_wallets = 0
        self.missing_pkeys = 0
        self.corrupted_wallets = 0
        self.algorithm_updates = 0
        self.algorithm_errors = 0
        self.vaults_created = 0
        self.vault_creation_errors = 0
        self.vaults_already_exist = 0
        self.vault_check_errors = 0
        self.flow_balance_checks = 0
        self.flow_funding_needed = 0
        self.flow_funding_success = 0
        self.flow_funding_errors = 0
        
        # Thread locks for statistics
        self.stats_lock = threading.Lock()
        
        # Account assignment for threading (1 account per thread)
        self.funder_accounts = [
            "mainnet-agfarms", "mainnet-agfarms-1", "mainnet-agfarms-2", 
            "mainnet-agfarms-3", "mainnet-agfarms-4", "mainnet-agfarms-5",
            "mainnet-agfarms-6", "mainnet-agfarms-7", "mainnet-agfarms-8"
        ]
        self.thread_accounts = {}  # Will store thread_id -> account mapping
        self.thread_lock = threading.Lock()
        
        # Global rate limiting (IP-based) - Flow RPC limits
        self.last_script_request_time = 0  # For ExecuteScript (5 RPS limit)
        self.last_transaction_request_time = 0  # For SendTransaction (50 RPS limit)
        self.script_request_interval = 0.2  # 200ms between script requests (5 RPS = 1 per 200ms)
        self.transaction_request_interval = 0.02  # 20ms between transaction requests (50 RPS = 1 per 20ms)
        self.rate_limit_lock = threading.Lock()
    
    def get_thread_account(self, thread_id):
        """Get the dedicated account for a specific thread"""
        with self.thread_lock:
            if thread_id not in self.thread_accounts:
                # Assign next available account to this thread
                account_index = len(self.thread_accounts) % len(self.funder_accounts)
                self.thread_accounts[thread_id] = self.funder_accounts[account_index]
                print(f"🔑 Assigned account {self.thread_accounts[thread_id]} to thread {thread_id}")
            return self.thread_accounts[thread_id]
    
    def rate_limit_script_request(self):
        """Rate limit for ExecuteScript requests (5 RPS limit)"""
        import time
        with self.rate_limit_lock:
            current_time = time.time()
            time_since_last = current_time - self.last_script_request_time
            
            if time_since_last < self.script_request_interval:
                sleep_time = self.script_request_interval - time_since_last
                thread_id = threading.current_thread().ident
                print(f"⏳ Script rate limiting: sleeping {sleep_time:.3f}s (Thread: {thread_id})")
                time.sleep(sleep_time)
            
            self.last_script_request_time = time.time()
    
    def rate_limit_transaction_request(self):
        """Rate limit for SendTransaction requests (50 RPS limit)"""
        import time
        with self.rate_limit_lock:
            current_time = time.time()
            time_since_last = current_time - self.last_transaction_request_time
            
            if time_since_last < self.transaction_request_interval:
                sleep_time = self.transaction_request_interval - time_since_last
                thread_id = threading.current_thread().ident
                print(f"⏳ Transaction rate limiting: sleeping {sleep_time:.3f}s (Thread: {thread_id})")
                time.sleep(sleep_time)
            
            self.last_transaction_request_time = time.time()
        
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
            # Ensure address has 0x prefix
            if not flow_address.startswith('0x'):
                flow_address = '0x' + flow_address
            
            # Use Flow wrapper to get account information
            result = self.flow_wrapper.get_account(flow_address, timeout=30)
            
            if not result.success:
                print(f"⚠️  Error checking algorithm for {flow_address}: {result.error_message}")
                return None, None
            
            # Extract signature algorithm info from the first key
            if result.data and 'keys' in result.data and len(result.data['keys']) > 0:
                # The keys field is now an array of strings (public keys), not objects
                # We need to get the key details separately
                key_public_key = result.data['keys'][0]
                
                # For now, we'll use defaults since the Flow CLI format has changed
                # In the future, we might need to use a different command to get key details
                signature_algo = "ECDSA_P256"  # Default to P256
                hash_algo = "SHA3_256"  # Default to SHA3_256
                
                print(f"🔍 Key found: {key_public_key[:20]}... (using defaults for algorithm)")
                
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
                
        except Exception as e:
            print(f"⚠️  Error checking algorithm for {flow_address}: {e}")
            return None, None
    
    def check_flow_balance(self, flow_address):
        """Check FLOW balance for a wallet using checkFlowBalance.cdc script"""
        try:
            # Ensure address has 0x prefix
            if not flow_address.startswith('0x'):
                flow_address = '0x' + flow_address
            
            # Use Flow wrapper to execute script
            result = self.flow_wrapper.execute_script(
                script_path="cadence/scripts/checkFlowBalance.cdc",
                args=[flow_address],
                timeout=30
            )
            
            if not result.success:
                # Check if it's a rate limit error
                if "rate limited" in result.error_message.lower() or "ResourceExhausted" in result.error_message:
                    thread_id = threading.current_thread().ident
                    print(f"⚠️  Rate limited checking FLOW balance for {flow_address}")
                    print(f"   📋 Full error: {result.error_message.strip()}")
                    print(f"   🔍 Command: {result.command}")
                    print(f"   🧵 Thread ID: {thread_id}")
                    return None
                print(f"⚠️  Error checking FLOW balance for {flow_address}: {result.error_message}")
                return None
            
            # Parse JSON output
            try:
                balance_data = result.data
                
                # The script returns a dictionary with key-value pairs
                if "value" in balance_data and isinstance(balance_data["value"], list):
                    # Find the FLOW_Balance entry in the value array
                    for item in balance_data["value"]:
                        if (isinstance(item, dict) and 
                            "key" in item and "value" in item and
                            item["key"].get("value") == "FLOW_Balance"):
                            balance_str = item["value"].get("value", "0.0")
                            balance = float(balance_str)
                            return balance
                    
                    # If FLOW_Balance not found, return 0
                    print(f"FLOW_Balance not found in response for {flow_address}")
                    return 0.0
                else:
                    print(f"Unexpected response format for {flow_address}: {balance_data}")
                    return None
                    
            except (ValueError, KeyError, TypeError) as e:
                print(f"Error parsing FLOW balance result for {flow_address}: {e}")
                return None
            
        except Exception as e:
            print(f"⚠️  Error checking FLOW balance for {flow_address}: {e}")
            return None
    
    def fund_wallet_with_flow(self, flow_address, amount=0.1, thread_id=None):
        """Fund a wallet with FLOW tokens using fundWallet.cdc transaction"""
        try:
            # Get thread-specific funder account
            if thread_id is None:
                thread_id = threading.current_thread().ident
            funder_account = self.get_thread_account(thread_id)
            
            # Ensure address has 0x prefix
            if not flow_address.startswith('0x'):
                flow_address = '0x' + flow_address
            
            print(f"🔍 DEBUG: Funding {flow_address} with {amount} FLOW")
            print(f"🔍 DEBUG: Using account: {funder_account}")
            
            # Use Flow wrapper to send transaction
            result = self.flow_wrapper.send_transaction(
                transaction_path="cadence/transactions/fundWallet.cdc",
                args=[flow_address, str(amount)],
                signer=funder_account,
                timeout=60
            )
            
            print(f"🔍 DEBUG: Return code: {0 if result.success else 1}")
            print(f"🔍 DEBUG: Stdout: {result.raw_output}")
            print(f"🔍 DEBUG: Stderr: {result.error_message}")
            
            if not result.success:
                # Check if it's a rate limit error
                if "rate limited" in result.error_message.lower() or "ResourceExhausted" in result.error_message:
                    print(f"⚠️  Rate limited funding {flow_address} with {amount} FLOW")
                    print(f"   📋 Full error: {result.error_message.strip()}")
                    print(f"   🔍 Command: {result.command}")
                    print(f"   🔑 Using account: {funder_account}")
                else:
                    print(f"❌ Error funding {flow_address} with {amount} FLOW: {result.error_message}")
                return False
            
            if result.transaction_id:
                print(f"✓ Funded {flow_address} with {amount} FLOW (Transaction: {result.transaction_id})")
            else:
                print(f"✓ Funded {flow_address} with {amount} FLOW")
            
            return True
                
        except Exception as e:
            print(f"❌ Error funding {flow_address} with {amount} FLOW: {e}")
            return False
    
    def check_bait_vault_exists(self, flow_address):
        """Check if BaitCoin vault exists for a wallet using checkBaitBalance.cdc script"""
        try:
            # Ensure address has 0x prefix
            if not flow_address.startswith('0x'):
                flow_address = '0x' + flow_address
            
            # Use Flow wrapper to execute script
            result = self.flow_wrapper.execute_script(
                script_path="cadence/scripts/checkBaitBalance.cdc",
                args=[flow_address],
                timeout=30
            )
            
            if result.success:
                # Script executed successfully, vault exists (even if balance is 0)
                return True
            else:
                # Check if error is about vault not existing
                if "Could not borrow BAIT vault reference" in result.error_message:
                    return False
                # Check if it's a rate limit error
                elif "rate limited" in result.error_message.lower() or "ResourceExhausted" in result.error_message:
                    thread_id = threading.current_thread().ident
                    print(f"⚠️  Rate limited checking vault for {flow_address}")
                    print(f"   📋 Full error: {result.error_message.strip()}")
                    print(f"   🔍 Command: {result.command}")
                    print(f"   🧵 Thread ID: {thread_id}")
                    return None
                else:
                    # Some other error occurred
                    print(f"⚠️  Error checking vault for {flow_address}: {result.error_message}")
                    return None
                    
        except Exception as e:
            print(f"⚠️  Error checking vault for {flow_address}: {e}")
            return None
    
    def create_bait_vault(self, flow_address, auth_id, thread_id=None):
        """Create BaitCoin vault for a wallet using createAllVault.cdc transaction"""
        try:
            # Get thread-specific payer account
            if thread_id is None:
                thread_id = threading.current_thread().ident
            payer_account = self.get_thread_account(thread_id)
            
            print(f"🔍 Creating vault for address: {flow_address}, auth_id: {auth_id}")
            
            # Use Flow wrapper to send transaction
            result = self.flow_wrapper.send_transaction(
                transaction_path="cadence/transactions/createAllVault.cdc",
                args=[f'0x{flow_address}'],
                signer=flow_address,  # Signer (target address)
                payer=payer_account,  # Rotating payer for fees
                timeout=60
            )
            
            print(f"🔍 DEBUG: Return code: {0 if result.success else 1}")
            print(f"🔍 DEBUG: Stdout: {result.raw_output}")
            print(f"🔍 DEBUG: Stderr: {result.error_message}")
            
            if not result.success:
                # Check if it's a rate limit error
                if "rate limited" in result.error_message.lower() or "ResourceExhausted" in result.error_message:
                    print(f"⚠️  Rate limited creating vault for {auth_id} ({flow_address})")
                    print(f"   📋 Full error: {result.error_message.strip()}")
                    print(f"   🔍 Command: {result.command}")
                    print(f"   🔑 Using payer: {payer_account}")
                else:
                    print(f"❌ Error creating vault for {auth_id} ({flow_address}): {result.error_message}")
                return False
            
            print(f"✓ Created BaitCoin vault for {auth_id} ({flow_address})")
            return True
                
        except Exception as e:
            print(f"❌ Error creating vault for {auth_id} ({flow_address}): {e}")
            return False
    
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
            # Only update signature_algorithm for now since other columns don't exist
            result = self.supabase.table('wallet').update({
                'signature_algorithm': signature_algorithm
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
    
    def process_wallet(self, wallet):
        """Process a single wallet (thread-safe)"""
        auth_id = wallet['auth_id']
        thread_id = threading.current_thread().ident
        
        try:
            # Validate wallet data
            if not self.validate_wallet_data(wallet):
                with self.stats_lock:
                    self.corrupted_wallets += 1
                return None
            
            # Check if pkey file exists
            if not self.check_pkey_file_exists(auth_id):
                print(f"⚠️  Missing pkey file for {auth_id}, creating it...")
                if not self.create_pkey_file(auth_id, wallet['flow_private_key']):
                    with self.stats_lock:
                        self.missing_pkeys += 1
                    return None
            
            # Get signature algorithm from database or use defaults
            signature_algorithm = wallet.get('signature_algorithm', 'ECDSA_P256')
            hash_algorithm = wallet.get('hash_algorithm', 'SHA3_256')
            
            # Check FLOW balance first
            print(f"🔍 Checking FLOW balance for {auth_id} ({wallet['flow_address']})...")
            flow_balance = self.check_flow_balance(wallet['flow_address'])
            
            with self.stats_lock:
                self.flow_balance_checks += 1
            
            if flow_balance is not None:
                print(f"💰 FLOW balance: {flow_balance} FLOW")
                
                # Check if funding is needed (below 0.075 FLOW)
                if flow_balance < 0.075:
                    print(f"💸 FLOW balance below 0.075, funding with 0.1 FLOW...")
                    with self.stats_lock:
                        self.flow_funding_needed += 1
                    
                    if self.fund_wallet_with_flow(wallet['flow_address'], 0.1, thread_id):
                        with self.stats_lock:
                            self.flow_funding_success += 1
                        print(f"✓ Successfully funded {auth_id} with 0.1 FLOW")
                    else:
                        with self.stats_lock:
                            self.flow_funding_errors += 1
                        print(f"❌ Failed to fund {auth_id} with FLOW")
                else:
                    print(f"✅ FLOW balance sufficient ({flow_balance} FLOW)")
            else:
                print(f"⚠️  Could not check FLOW balance for {auth_id}")
            
            # Check if BaitCoin vault already exists
            print(f"🔍 Checking if BaitCoin vault exists for {auth_id} ({wallet['flow_address']})...")
            vault_exists = self.check_bait_vault_exists(wallet['flow_address'])
            
            if vault_exists is True:
                print(f"✓ BaitCoin vault already exists for {auth_id} ({wallet['flow_address']})")
                with self.stats_lock:
                    self.vaults_already_exist += 1
            elif vault_exists is False:
                # Vault doesn't exist, create it
                print(f"🔍 Creating BaitCoin vault for {auth_id} ({wallet['flow_address']})...")
                if self.create_bait_vault(wallet['flow_address'], auth_id, thread_id):
                    with self.stats_lock:
                        self.vaults_created += 1
                else:
                    with self.stats_lock:
                        self.vault_creation_errors += 1
            else:
                # Error checking vault existence
                print(f"⚠️  Could not check vault existence for {auth_id} ({wallet['flow_address']})")
                with self.stats_lock:
                    self.vault_check_errors += 1
            
            # Return wallet config for production file
            wallet_config = {
                "address": wallet['flow_address'],
                "key": {
                    "type": "file",
                    "location": f"accounts/pkeys/{auth_id}.pkey",
                    "signatureAlgorithm": signature_algorithm,
                    "hashAlgorithm": hash_algorithm
                }
            }
            
            with self.stats_lock:
                self.synced_wallets += 1
            
            return {auth_id: wallet_config}
            
        except Exception as e:
            print(f"❌ Error processing wallet {auth_id}: {e}")
            with self.stats_lock:
                self.corrupted_wallets += 1
            return None

    def create_production_config(self, wallets):
        """Create flow-production.json from wallet data using threading"""
        production_config = {
            "accounts": {}
        }
        
        print(f"🚀 Processing {len(wallets)} wallets with threading...")
        print(f"🔄 Using {len(self.funder_accounts)} dedicated accounts (1 per thread)")
        print(f"⏳ Script rate limiting: {self.script_request_interval}s between ExecuteScript requests (5 RPS limit)")
        print(f"⏳ Transaction rate limiting: {self.transaction_request_interval}s between SendTransaction requests (50 RPS limit)")
        print(f"🧵 Using 2 threads to respect Flow network rate limits")
        
        # Use ThreadPoolExecutor for parallel processing (reduced to 2 workers to respect IP rate limits)
        with ThreadPoolExecutor(max_workers=2) as executor:
            # Submit all wallet processing tasks
            future_to_wallet = {
                executor.submit(self.process_wallet, wallet): wallet 
                for wallet in wallets
            }
            
            # Collect results as they complete
            for future in as_completed(future_to_wallet):
                wallet = future_to_wallet[future]
                try:
                    result = future.result()
                    if result:
                        production_config["accounts"].update(result)
                except Exception as e:
                    print(f"❌ Error processing wallet {wallet.get('auth_id', 'unknown')}: {e}")
                    with self.stats_lock:
                        self.corrupted_wallets += 1
        
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
        
        # Flow CLI commands will run from the flow directory explicitly
        print(f"📁 Flow CLI commands will run from: {self.flow_dir}")
        
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
        print(f"- FLOW balance checks: {self.flow_balance_checks}")
        print(f"- FLOW funding needed: {self.flow_funding_needed}")
        print(f"- FLOW funding successful: {self.flow_funding_success}")
        print(f"- FLOW funding errors: {self.flow_funding_errors}")
        print(f"- BaitCoin vaults already exist: {self.vaults_already_exist}")
        print(f"- BaitCoin vaults created: {self.vaults_created}")
        print(f"- Vault creation errors: {self.vault_creation_errors}")
        print(f"- Vault check errors: {self.vault_check_errors}")
        print(f"- Production config saved to: {self.production_file}")
        
        # Print Flow wrapper metrics
        flow_metrics = self.flow_wrapper.get_metrics()
        print(f"\n📊 Flow CLI Operations Summary:")
        print(f"- Total operations: {flow_metrics['total_operations']}")
        print(f"- Successful operations: {flow_metrics['successful_operations']}")
        print(f"- Failed operations: {flow_metrics['failed_operations']}")
        print(f"- Success rate: {flow_metrics['success_rate_percent']}%")
        print(f"- Average execution time: {flow_metrics['average_execution_time']}s")
        print(f"- Total retries: {flow_metrics['total_retries']}")
        print(f"- Rate limited operations: {flow_metrics['rate_limited_operations']}")
        print(f"- Timeout operations: {flow_metrics['timeout_operations']}")
        
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
