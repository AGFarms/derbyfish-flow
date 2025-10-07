#!/usr/bin/env python3
"""
Flow Wallet Funding Daemon

This daemon monitors and funds Flow wallets to maintain a 0.1 FLOW balance:
1. Fetches all users from Supabase auth
2. Checks each user's Flow balance
3. Funds wallets that have less than 0.1 FLOW
4. Runs as a daemon, checking every hour

Usage:
    python3 fundWallets.py
"""

import json
import os
import sys
import time
import signal
import threading
import queue
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv
from flow_wrapper import FlowWrapper, FlowConfig, FlowNetwork, FlowResult

# Load environment variables from .env file
load_dotenv()

# Configuration
TARGET_BALANCE = 0.1  # FLOW
FUNDING_AMOUNT = 0.1  # FLOW to send when funding
CHECK_INTERVAL = 3600  # 1 hour in seconds
FUNDER_ACCOUNT = "mainnet-agfarms"  # Account that funds other wallets
NETWORK = "mainnet"
TRANSACTION_TIMEOUT = 300  # 5 minutes timeout for transaction sealing
RATE_LIMIT_DELAY = 1.0  # Delay between requests to avoid rate limiting
BALANCE_CHECK_THREADS = 8  # Number of threads for balance checking

# Supabase configuration
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

class FlowWalletDaemon:
    def __init__(self):
        self.running = True
        self.supabase = None
        self.flow_dir = Path("flow")
        self.lock = threading.Lock()  # Thread safety lock
        self.transaction_queue = queue.Queue()  # Queue for sequential transaction processing
        self.transaction_worker = None  # Single worker thread for transactions
        
        # Initialize Flow wrapper
        self.flow_wrapper = FlowWrapper(FlowConfig(
            network=FlowNetwork.MAINNET,
            flow_dir=self.flow_dir,
            timeout=60,
            max_retries=3,
            rate_limit_delay=0.02,  # 20ms for 50 RPS limit
            json_output=True
        ))
        
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
        """Get the Flow CLI binary path (now handled by Flow wrapper)"""
        return self.flow_wrapper.flow_binary
    
    def get_all_wallets(self):
        """Get all wallets from the wallet table with pagination"""
        try:
            all_wallets = []
            page = 1
            per_page = 1000
            
            while True:
                result = self.supabase.table('wallet').select('*').range(
                    (page - 1) * per_page, 
                    page * per_page - 1
                ).execute()
                
                if not result.data or len(result.data) == 0:
                    break
                
                all_wallets.extend(result.data)
                
                if len(result.data) < per_page:
                    break
                    
                page += 1
            
            return all_wallets
            
        except Exception as e:
            print(f"Error fetching wallets from database: {e}")
            return []
    
    
    def check_flow_balance(self, address):
        """Check Flow token balance for an address using dedicated script"""
        try:
            # Use Flow wrapper to execute script
            result = self.flow_wrapper.execute_script(
                script_path="cadence/scripts/checkFlowBalance.cdc",
                args=[address],
                timeout=30
            )
            
            if not result.success:
                # Check if it's a rate limit error
                if "rate limited" in result.error_message.lower():
                    print(f"⚠️  Rate limited for {address}, will retry later")
                    return None
                print(f"Error checking balance for {address}: {result.error_message}")
                return None
            
            # Parse the JSON result
            try:
                balance_data = result.data
                
                # The script returns a dictionary with a "value" array containing key-value pairs
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
                    print(f"FLOW_Balance not found in response for {address}")
                    return 0.0
                else:
                    print(f"Unexpected response format for {address}: {balance_data}")
                    return None
                    
            except (ValueError, KeyError, TypeError) as e:
                print(f"Error parsing balance result for {address}: {e}")
                return None
            
        except Exception as e:
            print(f"Error checking Flow balance for {address}: {e}")
            return None
    
    
    def wait_for_transaction_seal(self, tx_id):
        """Wait for a transaction to be sealed"""
        try:
            # Use Flow wrapper to wait for transaction seal
            result = self.flow_wrapper.wait_for_transaction_seal(tx_id, timeout=TRANSACTION_TIMEOUT)
            return result.success
            
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
                
                wallet, needed, funding_amount = task
                auth_id = wallet['auth_id']
                flow_address = wallet['flow_address']
                
                with self.lock:
                    print(f"💸 Processing funding for {auth_id} - sending {funding_amount} FLOW")
                
                # Fund the wallet
                if self.fund_wallet(flow_address, funding_amount):
                    # Wait a moment for the transaction to propagate
                    time.sleep(3)
                    
                    # Verify the balance after funding
                    new_balance = self.check_flow_balance(flow_address)
                    if new_balance is not None:
                        balance_increase = new_balance - (new_balance - funding_amount)
                        with self.lock:
                            print(f"✅ Successfully funded {auth_id} - Balance increased by {balance_increase:.6f} FLOW (new balance: {new_balance:.6f} FLOW)")
                    else:
                        with self.lock:
                            print(f"⚠️  Funded {auth_id} but could not verify new balance")
                else:
                    with self.lock:
                        print(f"❌ Failed to fund {auth_id}")
                
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
    
    def fund_wallet(self, to_address, amount):
        """Fund a wallet with Flow tokens using dedicated transaction"""
        try:
            # Use Flow wrapper to send transaction
            result = self.flow_wrapper.send_transaction(
                transaction_path="cadence/transactions/fundWallet.cdc",
                args=[f'0x{to_address}', str(amount)],
                signer=FUNDER_ACCOUNT,
                timeout=60
            )
            
            if not result.success:
                # Check for sequence number errors
                if "sequence number" in result.error_message.lower():
                    print(f"⚠️  Sequence number error for {to_address}, will retry later")
                    return False
                print(f"Error funding wallet {to_address}: {result.error_message}")
                return False
            
            if not result.transaction_id:
                print(f"Could not extract transaction ID for {to_address}")
                return False
            
            print(f"🔄 Transaction {result.transaction_id} sent for {to_address}, waiting for seal...")
            
            # Wait for transaction to seal
            if not self.wait_for_transaction_seal(result.transaction_id):
                return False
            
            print(f"✓ Transaction {result.transaction_id} sealed for {to_address}")
            return True
            
        except Exception as e:
            print(f"Error funding wallet {to_address}: {e}")
            return False
    
    def process_wallet(self, wallet):
        """Process a single wallet - check balance and queue funding if needed"""
        auth_id = wallet['auth_id']
        flow_address = wallet['flow_address']
        
        # Add rate limiting delay
        time.sleep(RATE_LIMIT_DELAY)
        
        with self.lock:
            print(f"🔍 Checking balance for {auth_id} ({flow_address})")
        
        # Check current balance
        balance = self.check_flow_balance(flow_address)
        if balance is None:
            with self.lock:
                print(f"❌ Could not check balance for {auth_id}")
            return False, False  # (success, queued_for_funding)
        
        with self.lock:
            print(f"💰 Current balance: {balance} FLOW")
        
        # Check if funding is needed
        if balance < TARGET_BALANCE:
            needed = TARGET_BALANCE - balance
            funding_amount = min(needed, FUNDING_AMOUNT)
            
            with self.lock:
                print(f"📝 Queueing funding for {auth_id} - needed: {needed} FLOW, sending: {funding_amount} FLOW")
            
            # Queue the funding task for sequential processing
            self.transaction_queue.put((wallet, needed, funding_amount))
            return True, True  # (success, queued_for_funding)
        else:
            with self.lock:
                print(f"✅ {auth_id} has sufficient balance ({balance} FLOW)")
            return True, False  # (success, queued_for_funding)
    
    def process_wallet_worker(self, wallet):
        """Worker function for processing a single wallet in a thread"""
        try:
            return self.process_wallet(wallet)
        except Exception as e:
            with self.lock:
                print(f"❌ Error processing wallet {wallet.get('auth_id', 'unknown')}: {e}")
            return False, False
    
    def run_cycle(self):
        """Run one complete funding cycle with parallel balance checking and sequential transactions"""
        print(f"\n🔄 Starting funding cycle at {datetime.now().isoformat()}")
        
        # Get all wallets
        wallets = self.get_all_wallets()
        if not wallets:
            print("No wallets found in database.")
            return
        
        print(f"📊 Processing {len(wallets)} wallets with {BALANCE_CHECK_THREADS} threads for balance checking...")
        
        successful_checks = 0
        queued_fundings = 0
        total_processed = 0
        failed_wallets = []
        
        # Process wallets in parallel for balance checking using ThreadPoolExecutor
        with ThreadPoolExecutor(max_workers=BALANCE_CHECK_THREADS) as executor:
            # Submit all wallet processing tasks
            future_to_wallet = {
                executor.submit(self.process_wallet_worker, wallet): wallet 
                for wallet in wallets
            }
            
            # Process completed tasks as they finish
            for future in as_completed(future_to_wallet):
                if not self.running:
                    # Cancel remaining futures if shutting down
                    for f in future_to_wallet:
                        f.cancel()
                    break
                
                wallet = future_to_wallet[future]
                auth_id = wallet['auth_id']
                
                try:
                    success, queued_for_funding = future.result()
                    if success:
                        successful_checks += 1
                        if queued_for_funding:
                            queued_fundings += 1
                    else:
                        failed_wallets.append(auth_id)
                    total_processed += 1
                    
                    with self.lock:
                        print(f"📊 Progress: {total_processed}/{len(wallets)} wallets processed")
                    
                except Exception as e:
                    with self.lock:
                        print(f"❌ Error processing wallet {auth_id}: {e}")
                    failed_wallets.append(auth_id)
                    total_processed += 1
        
        # Wait for all queued transactions to complete
        if queued_fundings > 0:
            print(f"⏳ Waiting for {queued_fundings} funding transactions to complete...")
            self.transaction_queue.join()  # Wait for all tasks to be processed
        
        print(f"\n📈 Cycle Summary:")
        print(f"- Processed: {total_processed} wallets")
        print(f"- Successful checks: {successful_checks} wallets")
        print(f"- Queued for funding: {queued_fundings} wallets")
        if failed_wallets:
            print(f"- Failed wallets: {len(failed_wallets)}")
            print(f"- Failed wallet IDs: {failed_wallets[:10]}{'...' if len(failed_wallets) > 10 else ''}")
        
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
        
        print(f"- Next check in {CHECK_INTERVAL} seconds")
    
    def run(self):
        """Main daemon loop"""
        print("🚀 Starting Flow Wallet Funding Daemon...")
        print(f"Target balance: {TARGET_BALANCE} FLOW")
        print(f"Funding amount: {FUNDING_AMOUNT} FLOW")
        print(f"Check interval: {CHECK_INTERVAL} seconds")
        print(f"Transaction timeout: {TRANSACTION_TIMEOUT} seconds")
        print(f"Funder account: {FUNDER_ACCOUNT}")
        print(f"Network: {NETWORK}")
        print(f"Balance checking: {BALANCE_CHECK_THREADS} threads (parallel)")
        print("Transactions: Sequential (1 at a time to avoid sequence number conflicts)")
        
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
        
        print("✅ Daemon initialized successfully")
        
        # Main daemon loop
        while self.running:
            try:
                self.run_cycle()
                
                if self.running:
                    print(f"⏰ Waiting {CHECK_INTERVAL} seconds until next check...")
                    time.sleep(CHECK_INTERVAL)
                    
            except KeyboardInterrupt:
                print("\n🛑 Received keyboard interrupt, shutting down...")
                break
            except Exception as e:
                print(f"❌ Error in daemon loop: {e}")
                print("⏰ Waiting 60 seconds before retrying...")
                time.sleep(60)
        
        # Stop the transaction worker thread
        if self.transaction_worker and self.transaction_worker.is_alive():
            print("🛑 Stopping transaction worker thread...")
            self.transaction_queue.put(None)  # Sentinel value to stop worker
            self.transaction_worker.join(timeout=10)  # Wait up to 10 seconds for worker to stop
        
        print("👋 Daemon stopped")

def main():
    daemon = FlowWalletDaemon()
    daemon.run()

if __name__ == "__main__":
    main()
