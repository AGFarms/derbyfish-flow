#!/usr/bin/env python3
"""
Flow Wallet Generator for All Users

This script generates Flow wallets for all users in Supabase auth:
1. Fetches all users from Supabase auth using service role
2. Skips users who already have wallets
3. Generates a unique Flow wallet for each user (multi-threaded)
4. Saves private keys to flow/accounts/ directory
5. Saves wallet data to the database

Usage:
    python3 generate_flow_accounts.py
"""

import subprocess
import json
import os
import sys
import uuid
import time
import threading
import queue
import signal
from pathlib import Path
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configuration
NETWORK = "mainnet"
TRANSACTION_TIMEOUT = 300  # 5 minutes timeout for transaction sealing
RATE_LIMIT_DELAY = 1.0  # Delay between requests to avoid rate limiting
MAX_WORKERS = 1  # Number of worker threads for wallet generation (must be 1 to avoid sequence conflicts)

# Supabase configuration
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

class FlowWalletGenerator:
    def __init__(self):
        self.running = True
        self.supabase = None
        self.flow_dir = Path("flow")
        self.flow_binary = None
        self.lock = threading.Lock()  # Thread safety lock
        self.transaction_queue = queue.Queue()  # Queue for sequential transaction processing
        self.transaction_worker = None  # Single worker thread for transactions
        self.wallets_data = {}  # Store generated wallet data
        self.successful_wallets = 0
        self.database_saves = 0
        self.skipped_wallets = 0
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        print(f"\n🛑 Received signal {signum}, shutting down gracefully...")
        self.running = False
        # Signal the transaction worker to stop
        if self.transaction_worker and self.transaction_worker.is_alive():
            self.transaction_queue.put(None)  # Sentinel value to stop worker
    
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
    
    def get_flow_binary(self):
        """Get the Flow CLI binary path"""
        if self.flow_binary:
            return self.flow_binary
            
        try:
            result = subprocess.run(['which', 'flow'], capture_output=True, text=True)
            if result.returncode == 0:
                self.flow_binary = result.stdout.strip()
                return self.flow_binary
            else:
                print("Error: Flow CLI not found. Please install Flow CLI.")
                return None
        except Exception as e:
            print(f"Error finding Flow CLI: {e}")
            return None

    def get_existing_wallets(self):
        """Get all existing wallet auth_ids from the database"""
        try:
            existing_wallets = set()
            page = 1
            per_page = 1000
            
            while True:
                result = self.supabase.table('wallet').select('auth_id').range(
                    (page - 1) * per_page, 
                    page * per_page - 1
                ).execute()
                
                if not result.data or len(result.data) == 0:
                    break
                
                for wallet in result.data:
                    existing_wallets.add(wallet['auth_id'])
                
                if len(result.data) < per_page:
                    break
                    
                page += 1
            
            print(f"Found {len(existing_wallets)} existing wallets in database")
            return existing_wallets
            
        except Exception as e:
            print(f"Error fetching existing wallets from database: {e}")
            return set()
    
    def get_all_users(self):
        """Get all users from Supabase auth with pagination, excluding those with existing wallets"""
        try:
            # First get existing wallets
            existing_wallets = self.get_existing_wallets()
            
            all_users = []
            page = 1
            per_page = 1000
            total_users_fetched = 0
            
            print(f"🔍 Starting to fetch users from Supabase auth...")
            print(f"📊 Found {len(existing_wallets)} existing wallets to skip")
            
            while True:
                print(f"📄 Fetching page {page} (per_page={per_page})...")
                result = self.supabase.auth.admin.list_users(per_page=per_page, page=page)
                
                if not result or len(result) == 0:
                    print(f"📄 Page {page} returned no users, stopping pagination")
                    break
                
                print(f"📄 Page {page} returned {len(result)} users")
                total_users_fetched += len(result)
                
                users_batch = []
                for user in result:
                    # Skip users who already have wallets
                    if user.id in existing_wallets:
                        self.skipped_wallets += 1
                        continue
                    
                    users_batch.append({
                        'id': user.id,
                        'auth_id': user.id,
                        'created_at': user.created_at
                    })
                
                print(f"📄 Page {page}: {len(users_batch)} users need wallets (skipped {len(result) - len(users_batch)} with existing wallets)")
                all_users.extend(users_batch)
                
                if len(result) < per_page:
                    print(f"📄 Page {page} had fewer users than per_page, stopping pagination")
                    break
                    
                page += 1
            
            print(f"📊 Total users fetched from auth: {total_users_fetched}")
            print(f"📊 Users needing wallets: {len(all_users)}")
            print(f"📊 Users skipped (already have wallets): {self.skipped_wallets}")
            return all_users
            
        except Exception as e:
            print(f"Error fetching users from Supabase auth: {e}")
            return []

    def generate_flow_wallet(self):
        """Generate a single Flow wallet using Flow CLI"""
        try:
            flow_binary = self.get_flow_binary()
            if not flow_binary:
                return None
            
            # First, generate a key pair
            cmd = f"{flow_binary} keys generate -o json"
            result = subprocess.run(
                cmd,
                cwd=self.flow_dir,
                capture_output=True,
                text=True,
                shell=True,
                timeout=60
            )
            
            if result.returncode != 0:
                print(f"Failed to generate key pair: {result.stderr}")
                return None
            
            key_data = json.loads(result.stdout.strip())
            public_key = key_data['public']
            
            # Now create an actual Flow account with the public key
            cmd = f"{flow_binary} accounts create --key {public_key} --network {NETWORK} -o json"
            result = subprocess.run(
                cmd,
                cwd=self.flow_dir,
                capture_output=True,
                text=True,
                shell=True,
                timeout=60
            )
            
            if result.returncode != 0:
                print(f"Failed to create account: {result.stderr}")
                return None
            
            account_data = json.loads(result.stdout.strip())
            account_address = account_data['address']
            
            # Return the key data with the actual account address
            return {
                'private': key_data['private'],
                'public': key_data['public'],
                'address': account_address
            }
            
        except Exception as e:
            print(f"Error generating wallet: {e}")
            return None
    
    def wait_for_transaction_seal(self, tx_id):
        """Wait for a transaction to be sealed"""
        try:
            flow_binary = self.get_flow_binary()
            if not flow_binary:
                return False
            
            start_time = time.time()
            while time.time() - start_time < TRANSACTION_TIMEOUT:
                cmd = f"{flow_binary} transactions get {tx_id} --network {NETWORK} -o json"
                result = subprocess.run(
                    cmd,
                    cwd=self.flow_dir,
                    capture_output=True,
                    text=True,
                    shell=True,
                    timeout=30
                )
                
                if result.returncode == 0:
                    try:
                        tx_data = json.loads(result.stdout.strip())
                        status = tx_data.get("status", "")
                        if status == "SEALED":
                            return True
                        elif status == "FAILED":
                            print(f"Transaction {tx_id} failed")
                            return False
                    except (ValueError, KeyError):
                        pass
                
                time.sleep(5)  # Wait 5 seconds before checking again
            
            print(f"Transaction {tx_id} timed out after {TRANSACTION_TIMEOUT} seconds")
            return False
            
        except Exception as e:
            print(f"Error waiting for transaction seal: {e}")
            return False
    
    def transaction_worker_thread(self):
        """Single worker thread that processes transactions sequentially"""
        while self.running:
            try:
                # Get next transaction from queue (blocks until available)
                task = self.transaction_queue.get(timeout=1)
                
                # Check for shutdown signal
                if task is None:
                    break
                
                user, key_data = task
                auth_id = user['auth_id']
                
                with self.lock:
                    print(f"💾 Processing database save for {auth_id}")
                
                # Save to database
                if self.save_wallet_to_database(auth_id, key_data):
                    with self.lock:
                        self.database_saves += 1
                        self.wallets_data[auth_id] = key_data
                        self.successful_wallets += 1
                        print(f"✅ Successfully saved wallet for {auth_id}: {key_data['address']}")
                else:
                    with self.lock:
                        print(f"❌ Failed to save wallet to database for {auth_id}")
                
                # Mark task as done
                self.transaction_queue.task_done()
                
            except queue.Empty:
                # Timeout waiting for task, continue loop
                continue
            except Exception as e:
                with self.lock:
                    print(f"❌ Error in transaction worker: {e}")
                # Mark task as done even if failed
                try:
                    self.transaction_queue.task_done()
                except ValueError:
                    pass  # Task was already marked as done

    def save_private_key(self, auth_id, private_key):
        """Save private key to .pkey file"""
        accounts_dir = self.flow_dir / "accounts"
        accounts_dir.mkdir(exist_ok=True)
        
        pkey_file = accounts_dir / f"{auth_id}.pkey"
        with open(pkey_file, 'w') as f:
            f.write(private_key)
        
        print(f"✓ Saved private key: {pkey_file}")

    def save_wallet_to_database(self, auth_id, key_data):
        """Save wallet data to the database using recommended pattern"""
        try:
            wallet_data = {
                'id': str(uuid.uuid4()),
                'created_at': datetime.now().isoformat(),
                'auth_id': auth_id,
                'flow_address': key_data['address'],
                'flow_private_key': key_data['private'],
                'flow_public_key': key_data['public']
            }
            
            result = self.supabase.table('wallet').insert(wallet_data).execute()
            
            if result.data:
                return True
            else:
                return False
                
        except Exception as e:
            print(f"Error saving wallet to database for user {auth_id}: {e}")
            return False

    def create_flow_production_config(self):
        """Create flow-production.json with all generated wallets"""
        accounts_dir = self.flow_dir / "accounts"
        accounts_dir.mkdir(exist_ok=True)
        
        production_config = {
            "accounts": {}
        }
        
        for auth_id, wallet_data in self.wallets_data.items():
            production_config["accounts"][auth_id] = {
                "address": wallet_data['address'],
                "key": {
                    "type": "file",
                    "location": f"{auth_id}.pkey",
                    "signatureAlgorithm": "ECDSA_secp256k1",
                    "hashAlgorithm": "SHA2_256"
                }
            }
        
        # Write flow-production.json
        production_file = accounts_dir / "flow-production.json"
        with open(production_file, 'w') as f:
            json.dump(production_config, f, indent=4)
        
        print(f"✓ Created flow-production.json with {len(production_config['accounts'])} accounts")
        return production_file
    
    def process_user_wallet(self, user):
        """Process a single user - generate wallet and queue for database save"""
        auth_id = user['auth_id']
        
        # Add rate limiting delay
        time.sleep(RATE_LIMIT_DELAY)
        
        print(f"🔑 Generating wallet for {auth_id}")
        
        # Generate Flow wallet (sequential processing avoids sequence conflicts)
        key_data = self.generate_flow_wallet()
        
        if key_data:
            print(f"✅ Generated wallet for {auth_id}: {key_data['address']}")
            
            # Save private key immediately
            self.save_private_key(auth_id, key_data['private'])
            
            # Queue the database save for sequential processing
            self.transaction_queue.put((user, key_data))
            
            return True
        else:
            print(f"❌ Failed to generate wallet for {auth_id}")
            return False
    
    def run(self):
        """Main wallet generation process with sequential processing"""
        print("🚀 Starting Flow wallet generation for all users...")
        print("Wallet generation will be processed sequentially to avoid Flow sequence number conflicts")
        print("Database saves will be processed sequentially to avoid conflicts")
        
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
        
        # Check if Flow CLI is available
        if not self.get_flow_binary():
            print("Error: Flow CLI not found. Please install Flow CLI.")
            sys.exit(1)
        
        # Start the transaction worker thread
        self.transaction_worker = threading.Thread(target=self.transaction_worker_thread, daemon=True)
        self.transaction_worker.start()
        
        # Get all users (excluding those with existing wallets)
        users = self.get_all_users()
        if not users:
            print("No users found that need wallets.")
            sys.exit(0)
        
        print(f"📊 Processing {len(users)} users...")
        
        # Process users sequentially to avoid Flow sequence number conflicts
        for user in users:
            if not self.running:
                break
                
            try:
                self.process_user_wallet(user)
            except Exception as e:
                print(f"❌ Error processing user {user['auth_id']}: {e}")
        
        # Wait for all queued database saves to complete
        if self.successful_wallets > 0:
            print(f"⏳ Waiting for {self.successful_wallets} database saves to complete...")
            self.transaction_queue.join()  # Wait for all tasks to be processed
        
        print(f"\n🎉 Summary:")
        print(f"- Processed: {len(users)} users")
        print(f"- Skipped: {self.skipped_wallets} users (already had wallets)")
        print(f"- Generated: {self.successful_wallets} wallets")
        print(f"- Saved to database: {self.database_saves} wallets")
        
        if self.successful_wallets > 0:
            # Create flow-production.json
            production_file = self.create_flow_production_config()
            print(f"- Configuration saved to {production_file}")
            
            # Show first few wallets as example
            print(f"\nFirst 3 wallets:")
            for i, (auth_id, data) in enumerate(list(self.wallets_data.items())[:3]):
                print(f"  {auth_id}: {data['address']}")
        else:
            print("No wallets were generated successfully.")
            sys.exit(1)

def main():
    generator = FlowWalletGenerator()
    generator.run()

if __name__ == "__main__":
    main()

