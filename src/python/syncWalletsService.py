#!/usr/bin/env python3
"""
Flow Wallet Sync Service

This service runs continuously to sync wallet data between the database and flow-production.json:
1. Fetches all wallet data from Supabase database
2. Updates flow-production.json with current database state
3. Ensures pkey files are in the correct pkeys/ subdirectory
4. Handles missing or corrupted wallet data gracefully
5. Publishes BaitCoin balance capabilities for all accounts
6. Runs as a Docker service with proper volume mounts

Usage:
    python3 syncWalletsService.py
"""

import json
import os
import sys
import re
import time
import signal
from pathlib import Path
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from flow_node_adapter import FlowNodeAdapter

# Load environment variables from .env file
load_dotenv()

# Configuration
NETWORK = "mainnet"
SYNC_INTERVAL = int(os.getenv('SYNC_INTERVAL', '300'))  # 5 minutes default

# Supabase configuration
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

class WalletSyncService:
    def __init__(self):
        self.supabase = None
        self.flow_dir = Path("/app/flow")
        self.accounts_dir = self.flow_dir / "accounts"
        self.pkeys_dir = self.accounts_dir / "pkeys"
        self.production_file = self.accounts_dir / "flow-production.json"
        
        # Initialize Flow node adapter
        self.flow_adapter = FlowNodeAdapter()
        
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
        self.balance_capabilities_published = 0
        self.balance_capability_errors = 0
        
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
        
        # Service control
        self.running = True
        self.last_sync_time = None
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        print(f"\n🛑 Received signal {signum}, shutting down gracefully...")
        self.running = False
    
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
                print("Error: SUPABASE_URL not set in environment")
                return None
                
            if not SUPABASE_SERVICE_KEY:
                print("Error: SUPABASE_SERVICE_ROLE_KEY not set in environment")
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
    
    def check_flow_balance(self, flow_address):
        """Check FLOW balance for a wallet using checkFlowBalance.cdc script"""
        try:
            # Ensure address has 0x prefix
            if not flow_address.startswith('0x'):
                flow_address = '0x' + flow_address
            
            # Use Flow adapter to execute script
            result = self.flow_adapter.execute_script(
                script_path="cadence/scripts/checkFlowBalance.cdc",
                args=[flow_address],
                network="mainnet"
            )
            
            if not result.get('success', False):
                # Check if it's a rate limit error
                error_msg = result.get('error_message', '') or result.get('stderr', '')
                if "rate limited" in error_msg.lower() or "ResourceExhausted" in error_msg:
                    thread_id = threading.current_thread().ident
                    print(f"⚠️  Rate limited checking FLOW balance for {flow_address}")
                    print(f"   📋 Full error: {error_msg.strip()}")
                    print(f"   🔍 Command: {result.get('command', 'unknown')}")
                    print(f"   🧵 Thread ID: {thread_id}")
                    return None
                print(f"⚠️  Error checking FLOW balance for {flow_address}: {error_msg}")
                return None
            
            # Parse JSON output
            try:
                balance_data = result.get('data', {})
                
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
            
            # Use Flow adapter to send transaction
            result = self.flow_adapter.send_transaction(
                transaction_path="cadence/transactions/fundWallet.cdc",
                args=[flow_address, str(amount)],
                proposer_wallet_id=funder_account,
                payer_wallet_id=funder_account,
                authorizer_wallet_ids=[funder_account],
                network="mainnet"
            )
            
            print(f"🔍 DEBUG: Return code: {0 if result.get('success', False) else 1}")
            print(f"🔍 DEBUG: Stdout: {result.get('stdout', '')}")
            print(f"🔍 DEBUG: Stderr: {result.get('stderr', '')}")
            
            if not result.get('success', False):
                # Check if it's a rate limit error
                error_msg = result.get('error_message', '') or result.get('stderr', '')
                if "rate limited" in error_msg.lower() or "ResourceExhausted" in error_msg:
                    print(f"⚠️  Rate limited funding {flow_address} with {amount} FLOW")
                    print(f"   📋 Full error: {error_msg.strip()}")
                    print(f"   🔍 Command: {result.get('command', 'unknown')}")
                    print(f"   🔑 Using account: {funder_account}")
                else:
                    print(f"❌ Error funding {flow_address} with {amount} FLOW: {error_msg}")
                return False
            
            if result.get('transaction_id'):
                print(f"✓ Funded {flow_address} with {amount} FLOW (Transaction: {result['transaction_id']})")
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
            
            # Use Flow adapter to execute script
            result = self.flow_adapter.execute_script(
                script_path="cadence/scripts/checkBaitBalance.cdc",
                args=[flow_address],
                network="mainnet"
            )
            
            if result.get('success', False):
                # Script executed successfully, vault exists (even if balance is 0)
                return True
            else:
                # Check if error is about vault not existing
                error_msg = result.get('error_message', '') or result.get('stderr', '')
                if "Could not borrow BAIT vault reference" in error_msg:
                    return False
                # Check if it's a rate limit error
                elif "rate limited" in error_msg.lower() or "ResourceExhausted" in error_msg:
                    thread_id = threading.current_thread().ident
                    print(f"⚠️  Rate limited checking vault for {flow_address}")
                    print(f"   📋 Full error: {error_msg.strip()}")
                    print(f"   🔍 Command: {result.get('command', 'unknown')}")
                    print(f"   🧵 Thread ID: {thread_id}")
                    return None
                else:
                    # Some other error occurred
                    print(f"⚠️  Error checking vault for {flow_address}: {error_msg}")
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
            
            # Use Flow adapter to send transaction
            result = self.flow_adapter.send_transaction(
                transaction_path="cadence/transactions/createAllVault.cdc",
                args=[f'0x{flow_address}'],
                proposer_wallet_id=flow_address,  # Proposer (target address)
                payer_wallet_id=payer_account,  # Rotating payer for fees
                authorizer_wallet_ids=[flow_address],  # Authorizer (target address)
                network="mainnet"
            )
            
            print(f"🔍 DEBUG: Return code: {0 if result.get('success', False) else 1}")
            print(f"🔍 DEBUG: Stdout: {result.get('stdout', '')}")
            print(f"🔍 DEBUG: Stderr: {result.get('stderr', '')}")
            
            if not result.get('success', False):
                # Check if it's a rate limit error
                error_msg = result.get('error_message', '') or result.get('stderr', '')
                if "rate limited" in error_msg.lower() or "ResourceExhausted" in error_msg:
                    print(f"⚠️  Rate limited creating vault for {auth_id} ({flow_address})")
                    print(f"   📋 Full error: {error_msg.strip()}")
                    print(f"   🔍 Command: {result.get('command', 'unknown')}")
                    print(f"   🔑 Using payer: {payer_account}")
                else:
                    print(f"❌ Error creating vault for {auth_id} ({flow_address}): {error_msg}")
                return False
            
            print(f"✓ Created BaitCoin vault for {auth_id} ({flow_address})")
            return True
                
        except Exception as e:
            print(f"❌ Error creating vault for {auth_id} ({flow_address}): {e}")
            return False
    
    def publish_bait_balance_capability(self, flow_address, auth_id, thread_id=None):
        """Publish BaitCoin balance capability for a wallet using publishBaitBalance.cdc transaction"""
        try:
            # Get thread-specific payer account
            if thread_id is None:
                thread_id = threading.current_thread().ident
            payer_account = self.get_thread_account(thread_id)
            
            print(f"🔍 Publishing BaitCoin balance capability for address: {flow_address}, auth_id: {auth_id}")
            
            # Use Flow adapter to send transaction
            result = self.flow_adapter.send_transaction(
                transaction_path="cadence/transactions/publishBaitBalance.cdc",
                args=[],
                proposer_wallet_id=flow_address,  # Proposer (target address)
                payer_wallet_id=payer_account,  # Rotating payer for fees
                authorizer_wallet_ids=[flow_address],  # Authorizer (target address)
                network="mainnet"
            )
            
            print(f"🔍 DEBUG: Return code: {0 if result.get('success', False) else 1}")
            print(f"🔍 DEBUG: Stdout: {result.get('stdout', '')}")
            print(f"🔍 DEBUG: Stderr: {result.get('stderr', '')}")
            
            if not result.get('success', False):
                # Check if it's a rate limit error
                error_msg = result.get('error_message', '') or result.get('stderr', '')
                if "rate limited" in error_msg.lower() or "ResourceExhausted" in error_msg:
                    print(f"⚠️  Rate limited publishing balance capability for {auth_id} ({flow_address})")
                    print(f"   📋 Full error: {error_msg.strip()}")
                    print(f"   🔍 Command: {result.get('command', 'unknown')}")
                    print(f"   🔑 Using payer: {payer_account}")
                else:
                    print(f"❌ Error publishing balance capability for {auth_id} ({flow_address}): {error_msg}")
                return False
            
            print(f"✓ Published BaitCoin balance capability for {auth_id} ({flow_address})")
            return True
                
        except Exception as e:
            print(f"❌ Error publishing balance capability for {auth_id} ({flow_address}): {e}")
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
            
            # Publish BaitCoin balance capability
            print(f"🔍 Publishing BaitCoin balance capability for {auth_id} ({wallet['flow_address']})...")
            if self.publish_bait_balance_capability(wallet['flow_address'], auth_id, thread_id):
                with self.stats_lock:
                    self.balance_capabilities_published += 1
            else:
                with self.stats_lock:
                    self.balance_capability_errors += 1
            
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
            import shutil
            
            # Create backup of existing file (use copy instead of rename to avoid "device busy" errors)
            if self.production_file.exists():
                backup_file = self.production_file.with_suffix('.json.backup')
                try:
                    shutil.copy2(self.production_file, backup_file)
                    print(f"📋 Created backup: {backup_file}")
                except Exception as backup_error:
                    print(f"⚠️  Could not create backup: {backup_error}")
                    # Continue anyway, backup is not critical
            
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
                
                # In service mode, we'll log but not delete automatically
                print("⚠️  Orphaned files detected but not deleted in service mode")
            else:
                print("✓ No orphaned pkey files found")
                
        except Exception as e:
            print(f"⚠️  Error during cleanup: {e}")
    
    def reset_statistics(self):
        """Reset statistics for next sync cycle"""
        with self.stats_lock:
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
            self.balance_capabilities_published = 0
            self.balance_capability_errors = 0
    
    def sync_wallets(self):
        """Perform a single wallet sync operation"""
        print(f"\n🔄 Starting wallet sync at {datetime.now().isoformat()}")
        
        # Ensure we're in the right directory
        if not self.flow_dir.exists():
            print("Error: flow directory not found.")
            return False
        
        # Flow CLI commands will run from the flow directory explicitly
        print(f"📁 Flow CLI commands will run from: {self.flow_dir}")
        
        # Initialize Supabase client
        self.supabase = self.get_supabase_client()
        if not self.supabase:
            print("Error: Could not initialize Supabase client.")
            return False
        
        # Get all wallets from database
        wallets = self.get_all_wallets_from_database()
        if not wallets:
            print("No wallets found in database.")
            return True
        
        self.total_wallets = len(wallets)
        print(f"📊 Processing {self.total_wallets} wallets...")
        
        # Create production config from database data
        production_config = self.create_production_config(wallets)
        
        # Save production config
        if not self.save_production_config(production_config):
            print("❌ Failed to save production config")
            return False
        
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
        print(f"- Balance capabilities published: {self.balance_capabilities_published}")
        print(f"- Balance capability errors: {self.balance_capability_errors}")
        print(f"- Production config saved to: {self.production_file}")
        
        # Print Flow adapter operations summary
        print(f"\n📊 Flow Operations Summary:")
        print(f"- Using FlowNodeAdapter for Flow CLI operations")
        print(f"- All operations logged with detailed debugging information")
        
        self.last_sync_time = datetime.now()
        return True
    
    def run_service(self):
        """Run the wallet sync service continuously"""
        print("🚀 Starting Flow Wallet Sync Service...")
        print(f"⏰ Sync interval: {SYNC_INTERVAL} seconds")
        print(f"🔄 Service will run continuously until stopped")
        
        # Perform initial sync
        if not self.sync_wallets():
            print("❌ Initial sync failed, exiting...")
            return
        
        # Main service loop
        while self.running:
            try:
                # Wait for next sync interval
                print(f"⏳ Waiting {SYNC_INTERVAL} seconds until next sync...")
                for _ in range(SYNC_INTERVAL):
                    if not self.running:
                        break
                    time.sleep(1)
                
                if not self.running:
                    break
                
                # Reset statistics for next cycle
                self.reset_statistics()
                
                # Perform sync
                if not self.sync_wallets():
                    print("❌ Sync failed, will retry on next interval")
                
            except KeyboardInterrupt:
                print("\n🛑 Service interrupted by user")
                break
            except Exception as e:
                print(f"❌ Unexpected error in service loop: {e}")
                print("⏳ Will retry on next interval")
        
        print("🛑 Wallet sync service stopped")

def main():
    service = WalletSyncService()
    service.run_service()

if __name__ == "__main__":
    main()
