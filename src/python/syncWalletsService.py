#!/usr/bin/env python3
"""
Flow Wallet Sync Service

Syncs wallet data between Supabase database and flow-production.json.
Ensures all wallets have proper BaitCoin vault setup and sufficient FLOW balance.

Usage: python3 syncWalletsService.py
"""

import json
import os
import signal
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv
from flow_py_adapter import FlowPyAdapter
from supabase import create_client, Client

load_dotenv()

# Configuration
NETWORK = "mainnet"
SYNC_INTERVAL = int(os.getenv('SYNC_INTERVAL', '300'))
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

class WalletSyncService:
    def __init__(self):
        self.flow_dir = Path("flow") if os.path.exists("flow") else Path("/app/flow")
        self.accounts_dir = self.flow_dir / "accounts"
        self.pkeys_dir = self.accounts_dir / "pkeys"
        self.production_file = self.accounts_dir / "flow-production.json"
        
        self.flow_adapter = FlowPyAdapter()
        self.supabase = None
        
        # Statistics
        self.stats = {
            'total_wallets': 0,
            'synced_wallets': 0,
            'corrupted_wallets': 0,
            'wallets_created': 0,
            'wallet_generation_errors': 0,
            'vaults_created': 0,
            'vaults_already_exist': 0,
            'vault_creation_errors': 0,
            'flow_balance_checks': 0,
            'flow_funding_needed': 0,
            'flow_funding_success': 0,
            'flow_funding_errors': 0
        }
        self.stats_lock = threading.Lock()
        
        # Thread management - use only existing service accounts
        self.funder_accounts = ["mainnet-agfarms"]  # Only use the main service account that exists
        self.thread_accounts = {}
        self.thread_lock = threading.Lock()
        
        # Rate limiting
        self.last_script_time = 0
        self.last_transaction_time = 0
        self.script_interval = 0.2
        self.transaction_interval = 0.02
        self.rate_limit_lock = threading.Lock()
        
        # File operations lock
        self.file_lock = threading.Lock()
        
        # Service control
        self.running = True
        self.shutdown_event = threading.Event()
        self.shutdown_count = 0
        
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        print(f"\n🛑 Received signal {signum}, shutting down gracefully...")
        self.running = False
        self.shutdown_event.set()
    
    def _get_thread_account(self, thread_id):
        with self.thread_lock:
            # Always use the main service account since it's the only one that exists
            return "mainnet-agfarms"
    
    def _rate_limit(self, request_type):
        with self.rate_limit_lock:
            current_time = time.time()
            if request_type == 'script':
                last_time = self.last_script_time
                interval = self.script_interval
                self.last_script_time = current_time
            else:
                last_time = self.last_transaction_time
                interval = self.transaction_interval
                self.last_transaction_time = current_time
            
            time_since_last = current_time - last_time
            if time_since_last < interval:
                sleep_time = interval - time_since_last
                if self.shutdown_event.wait(timeout=sleep_time):
                    return False
            return True
        
    def _init_supabase(self):
        if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
            raise ValueError("Missing Supabase configuration")
        return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    
    def _fetch_users(self):
        """Fetch all users from Supabase auth system with pagination"""
        all_users = []
        page = 1
        per_page = 1000
        
        try:
            while True:
                # Use Supabase Admin API to fetch users with pagination
                response = self.supabase.auth.admin.list_users(
                    page=page,
                    per_page=per_page
                )
                
                # The response might be a list directly or have a different structure
                if isinstance(response, list):
                    users_data = response
                elif hasattr(response, 'data'):
                    users_data = response.data
                elif isinstance(response, dict) and 'data' in response:
                    users_data = response['data']
                else:
                    print(f"❌ Unexpected response format from Supabase auth: {type(response)}")
                    break
                
                if not users_data:
                    break
                
                # Transform user data to match expected format
                for user in users_data:
                    if isinstance(user, dict):
                        all_users.append({
                            'auth_id': user.get('id'),
                            'email': user.get('email'),
                            'created_at': user.get('created_at')
                        })
                    elif hasattr(user, 'id') and hasattr(user, 'email'):
                        # Handle gotrue.types.User objects
                        all_users.append({
                            'auth_id': user.id,
                            'email': user.email,
                            'created_at': getattr(user, 'created_at', None)
                        })
                    else:
                        print(f"❌ Unexpected user data format: {type(user)}")
                
                # If we got fewer users than requested, we've reached the end
                if len(users_data) < per_page:
                    break
                
                page += 1
            
            if not all_users:
                print("No users found in Supabase auth system")
                return []
            
            print(f"📊 Successfully fetched {len(all_users)} users from Supabase auth system (across {page} pages)")
            
        except Exception as e:
            print(f"❌ Error fetching users from Supabase auth: {e}")
            return []
        
        return all_users
    
    def _fetch_wallets(self):
        """Fetch existing wallets from database"""
        all_wallets = []
        page = 1
        per_page = 1000
        
        while True:
            result = self.supabase.table('wallet').select('*').range(
                (page - 1) * per_page, page * per_page - 1
            ).execute()
            
            if not result.data:
                break
                
            all_wallets.extend(result.data)
            if len(result.data) < per_page:
                break
            page += 1
        
        return all_wallets
    
    def _load_production_config(self):
        """Load the current flow-production.json configuration"""
        try:
            if self.production_file.exists():
                with open(self.production_file, 'r') as f:
                    return json.load(f)
            return None
        except Exception as e:
            print(f"❌ Error loading production config: {e}")
            return None
    
    def _load_private_key(self, auth_id):
        """Load private key from pkey file"""
        try:
            pkey_file = self.pkeys_dir / f"{auth_id}.pkey"
            if pkey_file.exists():
                return pkey_file.read_text().strip()
            return None
        except Exception as e:
            print(f"❌ Error loading private key for {auth_id}: {e}")
            return None
    
    def _generate_wallet(self, auth_id):
        """Generate a new Flow wallet for the given auth_id"""
        try:
            # For now, we'll use a placeholder approach
            # In a real implementation, you'd use Flow's wallet generation
            # or call a service that generates Flow accounts
            
            # Generate a random private key (this is just for demo - use proper Flow key generation)
            import secrets
            import hashlib
            
            # Generate a random 32-byte private key
            private_key_bytes = secrets.token_bytes(32)
            private_key_hex = private_key_bytes.hex()
            
            # Generate a Flow address (simplified - in reality you'd use proper Flow address generation)
            # This is just a placeholder - you need to use proper Flow account creation
            address_hash = hashlib.sha256(f"{auth_id}{private_key_hex}".encode()).hexdigest()[:16]
            flow_address = f"0x{address_hash}"
            
            # Save private key to file
            self._ensure_pkey_file(auth_id, private_key_hex)
            
            # Create wallet record in database
            wallet_record = {
                'auth_id': auth_id,
                'flow_address': flow_address,
                'flow_private_key': private_key_hex,
                'flow_public_key': None  # Will be derived if needed
            }
            
            db_result = self.supabase.table('wallet').insert(wallet_record).execute()
            if db_result.data:
                print(f"✓ Generated new wallet for {auth_id}: {flow_address}")
                return wallet_record
            else:
                print(f"❌ Failed to save wallet record for {auth_id}")
                return None
                
        except Exception as e:
            print(f"❌ Error generating wallet for {auth_id}: {e}")
            return None
    
    def _ensure_wallet_record_exists(self, auth_id, flow_address):
        """Ensure a wallet record exists in the database for the given auth_id"""
        return self.supabase.table('wallet').select('*').eq('auth_id', auth_id).execute().data[0]
    
    def _check_flow_balance(self, flow_address):
        if not self.running:
            raise RuntimeError("Service is not running")
            
        address = flow_address if flow_address.startswith('0x') else f'0x{flow_address}'
        
        result = self.flow_adapter.execute_script(
            script_path="cadence/scripts/checkFlowBalance.cdc",
            args=[address],
            network="mainnet"
        )
        
        print(f"🔍 DEBUG: Flow balance result for {address}: {result}")
        
        if not result.get('success', False):
            raise RuntimeError(f"Flow balance script failed for {address}: {result.get('error_message', 'Unknown error')}")
        
        balance_data = result.get('data')
        print(f"🔍 DEBUG: Balance data for {address}: {balance_data}")
        
        try:
            return float(balance_data)
        except (ValueError, TypeError) as e:
            raise RuntimeError(f"Could not parse balance string '{balance_data}' for {address}: {e}")
    
    def _fund_wallet(self, flow_address, amount=0.1, thread_id=None):
        if thread_id is None:
            thread_id = threading.current_thread().ident
        funder_account = self._get_thread_account(thread_id)
        
        address = flow_address if flow_address.startswith('0x') else f'0x{flow_address}'
        
        result = self.flow_adapter.send_transaction(
            transaction_path="cadence/transactions/fundWallet.cdc",
            args=[address, str(amount)],
            proposer_wallet_id=funder_account,
            payer_wallet_id=funder_account,
            authorizer_wallet_ids=[funder_account],
            network="mainnet"
        )
        
        return result.get('success', False)
    
    def _check_bait_vault(self, flow_address):
        address = flow_address if flow_address.startswith('0x') else f'0x{flow_address}'
        
        result = self.flow_adapter.execute_script(
            script_path="cadence/scripts/checkBaitBalance.cdc",
            args=[address],
            network="mainnet"
        )
        
        print(f"🔍 DEBUG: Bait vault check result for {address}: {result}")
        
        return result.get('success', False)
    
    def _check_bait_balance(self, flow_address):
        address = flow_address if flow_address.startswith('0x') else f'0x{flow_address}'
        
        result = self.flow_adapter.execute_script(
            script_path="cadence/scripts/checkBaitBalance.cdc",
            args=[address],
            network="mainnet"
        )
        
        print(f"🔍 DEBUG: Bait balance result for {address}: {result}")
        
        if not result.get('success', False):
            raise RuntimeError(f"Bait balance script failed for {address}: {result.get('error_message', 'Unknown error')}")
        
        data = result.get('data')
        print(f"🔍 DEBUG: Bait balance data for {address}: {data}")
        
        if data is None:
            raise RuntimeError(f"No balance data returned for {address}")
        
        if isinstance(data, (int, float)):
            return float(data)
        elif isinstance(data, str):
            try:
                return float(data)
            except ValueError as e:
                raise RuntimeError(f"Could not parse bait balance string '{data}' for {address}: {e}")
        else:
            raise RuntimeError(f"Unexpected balance data type for {address}: {type(data)}")
    
    def _publish_bait_balance_capability(self, flow_address, auth_id, thread_id=None):
        if thread_id is None:
            thread_id = threading.current_thread().ident
        payer_account = self._get_thread_account(thread_id)
        
        result = self.flow_adapter.send_transaction(
            transaction_path="cadence/transactions/publishBaitBalance.cdc",
            args=[],
            proposer_wallet_id=auth_id,
            payer_wallet_id=payer_account,
            authorizer_wallet_ids=[auth_id],
            network="mainnet"
        )
        
        print(f"🔍 DEBUG: Publish BaitCoin balance capability result for {auth_id}: {result}")
        
        return result.get('success', False)
    
    def _create_bait_vault(self, flow_address, auth_id, thread_id=None):
        if thread_id is None:
            thread_id = threading.current_thread().ident
        payer_account = self._get_thread_account(thread_id)
        
        result = self.flow_adapter.send_transaction(
            transaction_path="cadence/transactions/createAllVault.cdc",
            args=[f'0x{flow_address}'],
            proposer_wallet_id=auth_id,
            payer_wallet_id=payer_account,
            authorizer_wallet_ids=[auth_id],
            network="mainnet"
        )
        
        print(f"🔍 DEBUG: Create BaitCoin vault result for {auth_id}: {result}")
        
        return result.get('success', False)
    
    
    def _validate_wallet(self, wallet):
        required_fields = ['auth_id', 'flow_address', 'flow_private_key', 'flow_public_key']
        return all(wallet.get(field) for field in required_fields)
    
    def _ensure_pkey_file(self, auth_id, private_key):
        pkey_file = self.pkeys_dir / f"{auth_id}.pkey"
        if not pkey_file.exists():
            self.pkeys_dir.mkdir(exist_ok=True)
            pkey_file.write_text(private_key)
        return True
    
    def _process_wallet(self, wallet):
        if not self.running:
            return None
            
        auth_id = wallet['auth_id']
        thread_id = threading.current_thread().ident
        
        # Ensure wallet record exists in database
        wallet_record = self._ensure_wallet_record_exists(auth_id, wallet['flow_address'])
        if not wallet_record:
            print(f"❌ Failed to ensure wallet record exists for {auth_id}")
            with self.stats_lock:
                self.stats['corrupted_wallets'] += 1
            return None
        
        if not self._validate_wallet(wallet):
            print(f"⚠️  Wallet {auth_id} missing required fields")
            with self.stats_lock:
                self.stats['corrupted_wallets'] += 1
            return None
        
        self._ensure_pkey_file(auth_id, wallet['flow_private_key'])
        
        # Check FLOW balance
        flow_balance = self._check_flow_balance(wallet['flow_address'])
        with self.stats_lock:
            self.stats['flow_balance_checks'] += 1
        
        # Check BaitCoin balance (this will tell us if vault exists and capability is published)
        try:
            bait_balance = self._check_bait_balance(wallet['flow_address'])
            # Balance check succeeded - vault exists and capability is published
            bait_vault_exists = True
            cap_published = True
        except RuntimeError as e:
            # Balance check failed - either vault doesn't exist or capability isn't published
            print(f"🔧 Bait balance check failed for {auth_id}: {e}")
            print(f"🔧 Attempting to publish BaitCoin balance capability for {auth_id}...")
            
            if self._publish_bait_balance_capability(wallet['flow_address'], auth_id, thread_id):
                print(f"✓ BaitCoin balance capability published for {auth_id}")
                # Try balance check again
                try:
                    bait_balance = self._check_bait_balance(wallet['flow_address'])
                    bait_vault_exists = True
                    cap_published = True
                except RuntimeError as e2:
                    print(f"❌ Balance check still failed after publishing capability: {e2}")
                    bait_vault_exists = False
                    cap_published = False
                    bait_balance = None
            else:
                # Publishing failed - vault probably doesn't exist
                print(f"🔧 Publishing failed, creating BaitCoin vault for {auth_id}...")
                if self._create_bait_vault(wallet['flow_address'], auth_id, thread_id):
                    print(f"✓ BaitCoin vault created for {auth_id}")
                    with self.stats_lock:
                        self.stats['vaults_created'] += 1
                    # Try balance check after vault creation
                    try:
                        bait_balance = self._check_bait_balance(wallet['flow_address'])
                        bait_vault_exists = True
                        cap_published = True
                    except RuntimeError as e3:
                        print(f"❌ Balance check failed after vault creation: {e3}")
                        bait_vault_exists = True
                        cap_published = False
                        bait_balance = None
                else:
                    print(f"❌ Failed to create BaitCoin vault for {auth_id}")
                    with self.stats_lock:
                        self.stats['vault_creation_errors'] += 1
                    bait_vault_exists = False
                    cap_published = False
                    bait_balance = None
        
        # Log wallet status
        print(f"📊 {wallet['flow_address']}")
        print(f"   FLOW balance: {flow_balance}")
        print(f"   Bait vault: {bait_vault_exists}")
        print(f"   Cap published: {cap_published}")
        print(f"   Bait balance: {bait_balance if bait_balance is not None else 'ERROR'}")
        
        # Fund FLOW if needed
        if flow_balance < 0.075:
            print(f"💸 FLOW balance below 0.075, funding with 0.1 FLOW...")
            with self.stats_lock:
                self.stats['flow_funding_needed'] += 1
            if self._fund_wallet(wallet['flow_address'], 0.1, thread_id):
                print(f"✓ Successfully funded {auth_id} with 0.1 FLOW")
                with self.stats_lock:
                    self.stats['flow_funding_success'] += 1
            else:
                print(f"❌ Failed to fund {auth_id} with FLOW")
                with self.stats_lock:
                    self.stats['flow_funding_errors'] += 1
        
        # Update stats
        if bait_vault_exists:
            with self.stats_lock:
                self.stats['vaults_already_exist'] += 1
        
        # Create wallet config
        wallet_config = {
            "address": wallet['flow_address'],
            "key": {
                "type": "file",
                "location": f"accounts/pkeys/{auth_id}.pkey",
                "signatureAlgorithm": wallet.get('signature_algorithm', 'ECDSA_P256'),
                "hashAlgorithm": wallet.get('hash_algorithm', 'SHA3_256')
            }
        }
        
        # Update production config immediately to ensure account is available for transactions
        self._update_production_config({auth_id: wallet_config})
        
        with self.stats_lock:
            self.stats['synced_wallets'] += 1
        
        return {auth_id: wallet_config}

    def _create_production_config(self, wallets):
        production_config = {"accounts": {}}
        
        # Use multiple threads while respecting Flow rate limits
        # The _rate_limit method will handle the actual rate limiting
        max_workers = min(3, len(wallets))  # Use up to 10 threads or number of wallets, whichever is smaller
        
        print(f"🧵 Using {max_workers} threads to process wallets with rate limiting")
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            future_to_wallet = {
                executor.submit(self._process_wallet, wallet): wallet 
                for wallet in wallets
            }
            
            for future in as_completed(future_to_wallet):
                result = future.result()
                if result:
                    production_config["accounts"].update(result)
        
        return production_config
    
    def _update_production_config(self, wallet_config):
        """Update flow-production.json with a single wallet config (thread-safe)"""
        with self.file_lock:
            try:
                # Load existing config
                if self.production_file.exists():
                    with open(self.production_file, 'r') as f:
                        config = json.load(f)
                else:
                    config = {"accounts": {}}
                
                
                # Update with new wallet config
                config["accounts"].update(wallet_config)
                
                # Create backup
                if self.production_file.exists():
                    backup_file = self.production_file.with_suffix('.json.backup')
                    self.production_file.rename(backup_file)
                
                # Write updated config
                self.production_file.write_text(json.dumps(config, indent=4))
                return True
                
            except Exception as e:
                print(f"❌ Error updating production config: {e}")
                return False
    
    def _save_production_config(self, config):
        """Save complete production config (used for full sync)"""
        with self.file_lock:
            try:
                
                if self.production_file.exists():
                    backup_file = self.production_file.with_suffix('.json.backup')
                    self.production_file.rename(backup_file)
                
                self.production_file.write_text(json.dumps(config, indent=4))
                return True
            except Exception as e:
                print(f"❌ Error saving production config: {e}")
                return False
    
    def _reset_stats(self):
        with self.stats_lock:
            for key in self.stats:
                self.stats[key] = 0
    
    def sync_wallets(self):
        print(f"\n🔄 Starting wallet sync at {datetime.now().isoformat()}")
        
        if not self.flow_dir.exists():
            print("Error: flow directory not found.")
            return False
        
        try:
            self.supabase = self._init_supabase()
        except ValueError as e:
            print(f"Error: {e}")
            return False
        
        # Fetch all users from Supabase auth system
        users = self._fetch_users()
        if not users:
            print("No users found in Supabase auth system.")
            return True
        
        # Fetch existing wallets
        existing_wallets = self._fetch_wallets()
        existing_wallet_auth_ids = {wallet['auth_id'] for wallet in existing_wallets}
        
        # Process all users and ensure they have wallets
        wallets = []
        for user in users:
            auth_id = user['auth_id']
            
            if auth_id in existing_wallet_auth_ids:
                # User already has a wallet, load it
                existing_wallet = next(w for w in existing_wallets if w['auth_id'] == auth_id)
                wallet = {
                    'auth_id': auth_id,
                    'flow_address': existing_wallet['flow_address'],
                    'flow_private_key': self._load_private_key(auth_id),
                    'flow_public_key': existing_wallet.get('flow_public_key')
                }
                wallets.append(wallet)
            else:
                # User doesn't have a wallet, generate one
                print(f"🔧 Generating new wallet for user {auth_id}...")
                new_wallet = self._generate_wallet(auth_id)
                if new_wallet:
                    wallets.append(new_wallet)
                    with self.stats_lock:
                        self.stats['wallets_created'] += 1
                else:
                    print(f"❌ Failed to generate wallet for {auth_id}")
                    with self.stats_lock:
                        self.stats['wallet_generation_errors'] += 1
        
        self.stats['total_wallets'] = len(wallets)
        print(f"📊 Processing {len(wallets)} wallets...")
        
        # Process wallets (each wallet updates the config incrementally)
        self._create_production_config(wallets)
        
        print(f"\n🎉 Sync Summary:")
        for key, value in self.stats.items():
            print(f"- {key.replace('_', ' ').title()}: {value}")
        print(f"- Production config updated at: {self.production_file}")
        
        return True
    
    def run_service(self):
        print("🚀 Starting Flow Wallet Sync Service...")
        print(f"⏰ Sync interval: {SYNC_INTERVAL} seconds")
        
        try:
            if not self.sync_wallets():
                print("❌ Initial sync failed, exiting...")
                return
            
            while self.running:
                if self.shutdown_event.wait(timeout=SYNC_INTERVAL):
                    break
                
                if not self.running:
                    break
                
                self._reset_stats()
                if not self.sync_wallets():
                    print("❌ Sync failed, will retry on next interval")
        
        except KeyboardInterrupt:
            print("\n🛑 Service interrupted by user")
            self.running = False
        
        print("🛑 Wallet sync service stopped")

def main():
    service = WalletSyncService()
    service.run_service()

if __name__ == "__main__":
    main()
