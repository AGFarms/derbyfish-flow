from flask import Flask, request, jsonify
import json
import os
import threading
import time
from datetime import datetime
import uuid
import jwt
import functools
from supabase import create_client, Client
from dotenv import load_dotenv
from flow_node_adapter import FlowNodeAdapter

# Load environment variables
load_dotenv()

app = Flask(__name__)

# Supabase configuration
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_ANON_KEY = os.getenv('SUPABASE_ANON_KEY')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
SUPABASE_JWT_SECRET = os.getenv('SUPABASE_JWT_SECRET')

# Admin configuration
ADMIN_SECRET_KEY = os.getenv('ADMIN_SECRET_KEY')

# Validate required environment variables
if not SUPABASE_URL:
    print("WARNING: SUPABASE_URL environment variable not set")
if not SUPABASE_ANON_KEY:
    print("WARNING: SUPABASE_ANON_KEY environment variable not set")
if not SUPABASE_SERVICE_KEY:
    print("WARNING: SUPABASE_SERVICE_ROLE_KEY environment variable not set - server-side operations may not work")
if not SUPABASE_JWT_SECRET:
    print("WARNING: SUPABASE_JWT_SECRET environment variable not set - JWT authentication will not work")
if not ADMIN_SECRET_KEY:
    print("WARNING: ADMIN_SECRET_KEY environment variable not set - admin operations will not work")

# Initialize Supabase client with service role key for server-side operations
# This bypasses RLS policies for server-side wallet lookups
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY) if SUPABASE_URL and SUPABASE_SERVICE_KEY else None

# Global storage for background tasks
background_tasks = {}

# Initialize Node-based Flow adapter
node_adapter = FlowNodeAdapter(repo_root=os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))

def verify_admin_secret(auth_header):
    """Verify admin secret key from Authorization header"""
    try:
        if not ADMIN_SECRET_KEY:
            print("WARNING: ADMIN_SECRET_KEY not configured")
            return False
        
        if not auth_header:
            print("Authentication failed: No Authorization header provided")
            return False
        
        # Check if it's a Bearer token
        if not auth_header.startswith('Bearer '):
            print("Authentication failed: Invalid authorization header format")
            return False
        
        # Extract the token
        token_parts = auth_header.split(' ')
        if len(token_parts) != 2:
            print("Authentication failed: Malformed authorization header")
            return False
            
        token = token_parts[1]
        
        if not token or token.strip() == '':
            print("Authentication failed: Empty token")
            return False
        
        # Simple string comparison for admin secret
        if token == ADMIN_SECRET_KEY:
            print("Admin authentication successful")
            return True
        else:
            print("Authentication failed: Invalid admin secret")
            return False
            
    except Exception as e:
        print(f"Admin authentication error: {str(e)}")
        return False

def verify_supabase_jwt(token):
    """Verify and decode Supabase JWT token"""
    try:
        if not SUPABASE_JWT_SECRET:
            print("WARNING: SUPABASE_JWT_SECRET not configured")
            return None
        
        # Decode the JWT header to check algorithm
        unverified_header = jwt.get_unverified_header(token)
        if unverified_header.get('alg') != 'HS256':
            print(f"Invalid JWT algorithm: {unverified_header.get('alg')}")
            return None
            
        # Decode and verify the JWT with proper options
        payload = jwt.decode(
            token, 
            SUPABASE_JWT_SECRET, 
            algorithms=['HS256'],
            options={
                'verify_signature': True,
                'verify_exp': True,
                'verify_iat': True,
                'verify_aud': False,  # Supabase doesn't use audience
                'verify_iss': False   # We'll check issuer manually if needed
            }
        )
        
        # Additional validation for Supabase tokens
        if not payload.get('sub'):
            print("JWT token missing 'sub' claim")
            return None
            
        # Check if token is expired (jwt.decode already does this, but let's be explicit)
        import time
        current_time = time.time()
        if payload.get('exp', 0) < current_time:
            print("JWT token has expired")
            return None
            
        print(f"JWT token verified successfully for user: {payload.get('sub')}")
        return payload
        
    except jwt.ExpiredSignatureError:
        print("JWT token has expired")
        return None
    except jwt.InvalidSignatureError:
        print("JWT token has invalid signature")
        return None
    except jwt.InvalidTokenError as e:
        print(f"Invalid JWT token: {e}")
        return None
    except Exception as e:
        print(f"Error verifying JWT: {e}")
        return None

def get_wallet_details(user_id):
    """Fetch wallet details for a user from Supabase"""
    try:
        if not supabase:
            print("WARNING: Supabase client not configured")
            return None
            
        # Query the wallet table for the user using auth_id
        # Using service role key to bypass RLS policies for server-side operations
        response = supabase.table('wallet').select('*').eq('auth_id', user_id).execute()
        
        if response.data and len(response.data) > 0:
            wallet_data = response.data[0]  # Return first wallet
            print(f"Found wallet for user {user_id}: {wallet_data.get('address', 'no address')}")
            return wallet_data
        else:
            print(f"No wallet found for auth_id: {user_id}")
            return None
    except Exception as e:
        print(f"Error fetching wallet details: {e}")
        return None

def get_wallet_address(wallet_details):
    """Helper function to get wallet address from wallet details"""
    if not wallet_details:
        return None
    # Try both possible address fields from the wallet table
    return wallet_details.get('address') or wallet_details.get('flow_address')

def get_wallet_id_by_address(address):
    """Get wallet ID by Flow address from Supabase"""
    if not supabase:
        print("Supabase client not initialized")
        return None
    
    try:
        # Remove 0x prefix if present
        clean_address = address.replace('0x', '') if address.startswith('0x') else address
        response = supabase.table('wallet').select('id').eq('flow_address', clean_address).execute()
        if response.data and len(response.data) > 0:
            return response.data[0]['id']
        else:
            print(f"No wallet found for address {address}")
            return None
    except Exception as e:
        print(f"Error fetching wallet ID by address: {e}")
        return None

def get_flow_address_by_user_id(user_id):
    """Get Flow address by user ID (auth_id) from Supabase"""
    if not supabase:
        print("Supabase client not initialized")
        return None
    
    try:
        response = supabase.table('wallet').select('flow_address').eq('auth_id', user_id).execute()
        if response.data and len(response.data) > 0:
            return response.data[0]['flow_address']
        else:
            print(f"No wallet found for user ID {user_id}")
            return None
    except Exception as e:
        print(f"Error fetching Flow address by user ID: {e}")
        return None

def get_or_create_admin_wallet():
    """Get admin wallet from the database (assumes it exists from migration)"""
    admin_wallet_id = '77ef3a77-19e8-49d9-bcc7-f89872378622'  # Fixed admin wallet ID from migration
    
    if not supabase:
        print("Supabase client not initialized")
        return None
    
    try:
        # Verify the admin wallet exists
        response = supabase.table('wallet').select('id, flow_address').eq('id', admin_wallet_id).execute()
        if response.data and len(response.data) > 0:
            wallet_data = response.data[0]
            print(f"Found admin wallet: {wallet_data['id']} with address {wallet_data['flow_address']}")
            return wallet_data['id']
        else:
            print(f"Admin wallet not found in database. Please run migration 004_add_admin_wallet.sql")
            return None
            
    except Exception as e:
        print(f"Error getting admin wallet: {e}")
        return None

def log_authenticated_user(user_payload, wallet_details):
    """Log authenticated user and wallet details"""
    user_id = user_payload.get('sub', 'unknown')
    email = user_payload.get('email', 'unknown')
    
    if wallet_details:
        wallet_address = get_wallet_address(wallet_details) or 'no address'
        wallet_type = wallet_details.get('wallet_type', 'unknown')
        is_active = wallet_details.get('is_active', False)
    else:
        wallet_address = 'no wallet'
        wallet_type = 'none'
        is_active = False
    
    print(f"=== AUTHENTICATED USER ===")
    print(f"User ID: {user_id}")
    print(f"Email: {email}")
    print(f"Wallet Address: {wallet_address}")
    print(f"Wallet Type: {wallet_type}")
    print(f"Wallet Active: {is_active}")
    print(f"Timestamp: {datetime.now().isoformat()}")
    print("==========================")

def require_admin_auth(f):
    """Decorator to require admin secret key authentication for endpoints"""
    @functools.wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            # Get Authorization header
            auth_header = request.headers.get('Authorization')
            
            # Verify the admin secret
            if not verify_admin_secret(auth_header):
                return jsonify({'error': 'Invalid or missing admin secret'}), 401
            
            return f(*args, **kwargs)
            
        except Exception as e:
            print(f"Admin authentication error: {str(e)}")
            return jsonify({'error': 'Authentication failed due to server error'}), 500
    
    return decorated_function

def require_auth(f):
    """Decorator to require JWT authentication for endpoints"""
    @functools.wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            # Get Authorization header
            auth_header = request.headers.get('Authorization')
            
            if not auth_header:
                print("Authentication failed: No Authorization header provided")
                return jsonify({'error': 'Authorization header is required'}), 401
            
            # Check if it's a Bearer token
            if not auth_header.startswith('Bearer '):
                print("Authentication failed: Invalid authorization header format")
                return jsonify({'error': 'Invalid authorization header format. Expected: Bearer <token>'}), 401
            
            # Extract the token
            token_parts = auth_header.split(' ')
            if len(token_parts) != 2:
                print("Authentication failed: Malformed authorization header")
                return jsonify({'error': 'Malformed authorization header'}), 401
                
            token = token_parts[1]
            
            if not token or token.strip() == '':
                print("Authentication failed: Empty token")
                return jsonify({'error': 'Token cannot be empty'}), 401
            
            # Verify the JWT token
            print(f"Verifying JWT token for endpoint: {request.endpoint}")
            user_payload = verify_supabase_jwt(token)
            if not user_payload:
                print("Authentication failed: JWT verification failed")
                return jsonify({'error': 'Invalid or expired token'}), 401
            
            # Get wallet details
            user_id = user_payload.get('sub')
            if not user_id:
                print("Authentication failed: No user ID in token")
                return jsonify({'error': 'Invalid token: missing user ID'}), 401
                
            wallet_details = get_wallet_details(user_id) if user_id else None
            
            # Log the authenticated user
            log_authenticated_user(user_payload, wallet_details)
            
            # Add user info to request context for use in the endpoint
            request.user_payload = user_payload
            request.wallet_details = wallet_details
            
            return f(*args, **kwargs)
            
        except Exception as e:
            print(f"Authentication error: {str(e)}")
            return jsonify({'error': 'Authentication failed due to server error'}), 500
    
    return decorated_function



def run_background_task(task_id, command, args=None, network="mainnet", task_type="script"):
    """Run a Flow command in the background and store the result"""
    start_time = datetime.now()
    
    try:
        # Update network if different
        if network != flow_wrapper.config.network.value:
            flow_wrapper.update_config(network=FlowNetwork(network))
        
        # Parse command to determine operation type
        if command.startswith('script execute'):
            script_path = command.replace('script execute ', '').replace('scripts execute ', '')
            result = flow_wrapper.execute_script(script_path, args)
        elif command.startswith('transactions send'):
            transaction_path = command.replace('transactions send ', '').replace('transaction send ', '')
            # For background tasks, we need to determine the roles based on the task type
            if 'admin' in transaction_path.lower():
                # Admin operations use mainnet-agfarms for all roles
                proposer = 'mainnet-agfarms'
                authorizer = 'mainnet-agfarms'
                payer = 'mainnet-agfarms'
            else:
                # User operations - hardcode proposer to mainnet-agfarms
                proposer = 'mainnet-agfarms'  # Hardcoded to mainnet-agfarms
                authorizers = ['mainnet-agfarms']  # Always include mainnet-agfarms
                payer = 'mainnet-agfarms'
                
                # Try to find user ID in args for additional authorizer
                for i, arg in enumerate(args):
                    if arg == '--authorizer' and i + 1 < len(args):
                        authorizers.append(args[i + 1])
                        break
            
            if 'admin' in transaction_path.lower():
                result = flow_wrapper.send_transaction(
                    transaction_path, 
                    args, 
                    proposer=proposer,
                    authorizer=authorizer,
                    payer=payer
                )
            else:
                result = flow_wrapper.send_transaction(
                    transaction_path, 
                    args, 
                    proposer=proposer,
                    authorizers=authorizers,
                    payer=payer
                )
        else:
            # For other commands, use the wrapper's internal command execution
            result = flow_wrapper._execute_command(flow_wrapper._build_base_command(command, args))
        
        # Convert FlowResult to legacy format for compatibility
        result = {
            'success': result.success,
            'stdout': result.raw_output,
            'stderr': result.error_message,
            'returncode': 0 if result.success else 1,
            'command': result.command,
            'execution_time': result.execution_time,
            'network': result.network,
            'transaction_id': result.transaction_id
        }
    except Exception as e:
        result = {
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'returncode': -1,
            'command': command,
            'execution_time': 0.0,
            'network': network
        }
    
    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds()
    
    # Store in memory
    background_tasks[task_id] = {
        'status': 'completed',
        'start_time': start_time.isoformat(),
        'end_time': end_time.isoformat(),
        'duration': duration,
        'result': result
    }

@app.route('/')
def index():
    """API documentation endpoint"""
    return jsonify({
        'message': 'Flow CLI HTTP Wrapper - UPDATED VERSION',
        'version': '1.0.1',
        'endpoints': {
            'auth': {
                'test_auth': 'GET /auth/test - Test JWT authentication',
                'auth_status': 'GET /auth/status - Check authentication configuration'
            },
            'scripts': {
                'check_bait_balance': 'GET /scripts/check-bait-balance?address=<address>',
                'check_contract_vaults': 'GET /scripts/check-contract-vaults',
                'create_vault_and_mint': 'POST /scripts/create-vault-and-mint',
                'sell_bait': 'POST /scripts/sell-bait',
                'test_bait_coin_admin': 'POST /scripts/test-bait-coin-admin'
            },
            'transactions': {
                'admin_burn_bait': 'POST /transactions/admin-burn-bait (amount, from_wallet?) - Burn from admin wallet or transfer from custodial wallet then burn',
                'admin_mint_bait': 'POST /transactions/admin-mint-bait (to_address, amount)',
                'admin_mint_fusd': 'POST /transactions/admin-mint-fusd (to_address, amount)',
                'check_contract_usdf_balance': 'GET /transactions/check-contract-usdf-balance',
                'create_all_vault': 'POST /transactions/create-all-vault (address)',
                'create_usdf_vault': 'POST /transactions/create-usdf-vault (address)',
                'reset_all_vaults': 'POST /transactions/reset-all-vaults',
                'send_bait': 'POST /transactions/send-bait (to_address, amount)',
                'send_fusd': 'POST /transactions/send-fusd (to_address, amount)',
                'swap_bait_for_fusd': 'POST /transactions/swap-bait-for-fusd (amount)',
                'swap_fusd_for_bait': 'POST /transactions/swap-fusd-for-bait (amount)',
                'withdraw_contract_usdf': 'POST /transactions/withdraw-contract-usdf (amount)',
                'deposit_flow': 'POST /transactions/deposit-flow (to_address, amount)'
            },
            'background': {
                'run_script': 'POST /background/run-script',
                'run_transaction': 'POST /background/run-transaction',
                'get_task_status': 'GET /background/task/<task_id>',
                'list_tasks': 'GET /background/tasks'
            }
        }
    })

# Authentication test endpoints
@app.route('/auth/status')
def auth_status():
    """Check authentication configuration status"""
    return jsonify({
        'supabase_url_configured': bool(SUPABASE_URL),
        'supabase_anon_key_configured': bool(SUPABASE_ANON_KEY),
        'supabase_service_key_configured': bool(SUPABASE_SERVICE_KEY),
        'supabase_jwt_secret_configured': bool(SUPABASE_JWT_SECRET),
        'supabase_client_initialized': bool(supabase),
        'admin_secret_key_configured': bool(ADMIN_SECRET_KEY),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/auth/test')
@require_auth
def test_auth():
    """Test JWT authentication endpoint"""
    return jsonify({
        'message': 'Authentication successful!',
        'user_id': request.user_payload.get('sub'),
        'email': request.user_payload.get('email'),
        'wallet_address': get_wallet_address(request.wallet_details),
        'wallet_type': request.wallet_details.get('wallet_type') if request.wallet_details else None,
        'wallet_active': request.wallet_details.get('is_active') if request.wallet_details else None,
        'timestamp': datetime.now().isoformat()
    })

# Script endpoints
@app.route('/scripts/check-bait-balance')
@require_auth
def check_bait_balance():
    """Check BAIT balance for an address"""
    print("=== CHECK BAIT BALANCE ENDPOINT CALLED ===")
    address = request.args.get('address')
    network = request.args.get('network', 'mainnet')
    
    # Use authenticated user's wallet address as default if not specified
    if not address:
        address = get_wallet_address(request.wallet_details)
        if address:
            print(f"Using authenticated user's wallet address: {address}")
        else:
            return jsonify({'error': 'Address parameter is required and no wallet address found for authenticated user'}), 400
    
    print(f"Address: {address}, Network: {network}")
    
    # Use Node adapter for script execution
    print(f"=== PYTHON APP SCRIPT EXECUTION ===")
    print(f"Script: checkBaitBalance.cdc")
    print(f"Address: {address}")
    print(f"Network: {network}")
    print(f"User ID: {request.user_payload.get('sub')}")
    print(f"Wallet Details: {request.wallet_details}")
    
    result = node_adapter.execute_script(
        script_path='cadence/scripts/checkBaitBalance.cdc',
        args=[address]
    )
    
    print(f"=== PYTHON APP SCRIPT RESULT ===")
    print(f"Result: {result}")
    print("=====================================")
    
    return jsonify({
        'success': result.get('success'),
        'stdout': result.get('stdout'),
        'stderr': result.get('stderr'),
        'returncode': result.get('returncode'),
        'data': result.get('data'),
        'execution_time': result.get('execution_time')
    })

# Transaction endpoints
@app.route('/transactions/admin-burn-bait', methods=['POST'])
@require_admin_auth
def admin_burn_bait():
    """Admin burn BAIT tokens from admin wallet or from a specified custodial wallet"""
    data = request.get_json() or {}
    amount = data.get('amount')
    from_wallet = data.get('from_wallet')  # Optional: if provided, burn from this wallet
    network = data.get('network', 'mainnet')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    # If from_wallet is specified, first transfer bait from that wallet to admin, then burn
    if from_wallet:
        print(f"=== ADMIN BURN BAIT FROM CUSTODIAL WALLET ===")
        print(f"Amount: {amount}")
        print(f"From Wallet: {from_wallet}")
        print(f"Network: {network}")
        print("Step 1: Look up wallet in database and get private key")
        print("=====================================")
        
        # Step 1: Look up the wallet in the database to get the private key
        # Remove 0x prefix if present
        wallet_address = from_wallet.replace('0x', '') if from_wallet.startswith('0x') else from_wallet
        
        try:
            # Query the wallet table to get the private key
            wallet_response = supabase.table('wallet').select('flow_private_key, flow_address, auth_id').eq('flow_address', wallet_address).execute()
            
            if not wallet_response.data or len(wallet_response.data) == 0:
                return jsonify({
                    'success': False,
                    'error': f'Wallet {from_wallet} not found in database',
                    'step': 'wallet_lookup'
                }), 404
            
            wallet_data = wallet_response.data[0]
            private_key = wallet_data.get('flow_private_key')
            flow_address = wallet_data.get('flow_address')
            auth_id = wallet_data.get('auth_id')
            
            if not private_key:
                return jsonify({
                    'success': False,
                    'error': f'No private key found for wallet {from_wallet}',
                    'step': 'private_key_lookup'
                }), 400
            
            print(f"Found wallet in database:")
            print(f"  Address: {flow_address}")
            print(f"  Auth ID: {auth_id}")
            print(f"  Has private key: {bool(private_key)}")
            
        except Exception as e:
            return jsonify({
                'success': False,
                'error': f'Database error looking up wallet: {str(e)}',
                'step': 'database_error'
            }), 500
        
        print("Step 2: Transfer bait from custodial wallet to admin wallet")
        print("=====================================")
        
        # Step 2: Transfer bait from custodial wallet to admin wallet
        # We need to use the custodial wallet as the authorizer for the send transaction
        # sendBait.cdc takes (to: Address, amount: UFix64) where signer is the sender
        admin_wallet_address = "0xed2202de80195438"  # Admin wallet address
        
        # For now, we'll need to create a temporary Flow account configuration
        # or modify the node adapter to accept private keys directly
        # This is a limitation - we need to either:
        # 1. Add the wallet to flow.json temporarily, or
        # 2. Modify the node adapter to accept private keys
        
        print("Step 2: Transfer bait from custodial wallet to admin wallet")
        print("=====================================")
        
        # Step 2: Transfer bait from custodial wallet to admin wallet using private key
        admin_wallet_address = "0xed2202de80195438"  # Admin wallet address
        
        # Use the new method with private keys
        transfer_result = node_adapter.send_transaction_with_private_key(
            transaction_path='cadence/transactions/sendBait.cdc',
            args=[admin_wallet_address, amount],  # Send TO admin wallet FROM custodial wallet
            roles={'proposer': from_wallet, 'authorizer': [from_wallet], 'payer': 'mainnet-agfarms'},
            private_keys={from_wallet: private_key}  # Pass the private key for the custodial wallet
        )
        
        if not transfer_result.get('success'):
            return jsonify({
                'success': False,
                'error': 'Failed to transfer bait from custodial wallet to admin wallet',
                'transfer_result': transfer_result,
                'step': 'transfer'
            }), 500
        
        print(f"Step 2 completed successfully. Transaction ID: {transfer_result.get('transaction_id')}")
        print("Step 3: Burn bait from admin wallet")
        print("=====================================")
        
        # Step 3: Burn the bait from admin wallet
        burn_result = node_adapter.send_transaction(
            transaction_path='cadence/transactions/adminBurnBait.cdc',
            args=[amount],
            roles={'proposer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms'}
        )
        
        if not burn_result.get('success'):
            return jsonify({
                'success': False,
                'error': 'Failed to burn bait from admin wallet after successful transfer',
                'transfer_result': transfer_result,
                'burn_result': burn_result,
                'step': 'burn'
            }), 500
        
        print(f"Step 3 completed successfully. Transaction ID: {burn_result.get('transaction_id')}")
        print("All steps completed successfully!")
        print("=====================================")
        
        return jsonify({
            'success': True,
            'message': 'Successfully burned bait from custodial wallet',
            'transfer_transaction_id': transfer_result.get('transaction_id'),
            'burn_transaction_id': burn_result.get('transaction_id'),
            'amount': amount,
            'from_wallet': from_wallet,
            'execution_time': transfer_result.get('execution_time', 0) + burn_result.get('execution_time', 0),
            'burned_from': from_wallet
        })
    else:
        print(f"=== ADMIN BURN BAIT FROM ADMIN WALLET ===")
        print(f"Amount: {amount}")
        print(f"Network: {network}")
        print("=====================================")
        
        # Use Node adapter for transaction execution from admin's own wallet
        result = node_adapter.send_transaction(
            transaction_path='cadence/transactions/adminBurnBait.cdc',
            args=[amount],
            roles={'proposer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms'}
        )
        
        # Check if the transaction actually succeeded
        if not result.get('success'):
            print(f"Admin burn transaction failed: {result.get('stderr', 'Unknown error')}")
            return jsonify({
                'success': False,
                'error': result.get('stderr') or result.get('errorMessage') or 'Transaction failed',
                'stdout': result.get('stdout'),
                'stderr': result.get('stderr'),
                'returncode': result.get('returncode'),
                'transaction_id': result.get('transaction_id'),
                'execution_time': result.get('execution_time'),
                'burned_from': 'admin_wallet'
            }), 400
        
        return jsonify({
            'success': True,
            'stdout': result.get('stdout'),
            'stderr': result.get('stderr'),
            'returncode': result.get('returncode'),
            'transaction_id': result.get('transaction_id'),
            'execution_time': result.get('execution_time'),
            'burned_from': 'admin_wallet'
        })

@app.route('/transactions/admin-mint-bait', methods=['POST'])
@require_admin_auth
def admin_mint_bait():
        
    """Admin mint BAIT tokens"""
    data = request.get_json() or {}
    amount = data.get('amount')
    to_address = data.get('to_address')
    network = data.get('network', 'mainnet')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    # to_address is required for admin operations
    if not to_address:
        return jsonify({'error': 'to_address parameter is required'}), 400
    
    # Get wallet IDs for transaction logging
    admin_wallet_id = get_or_create_admin_wallet()  # Admin wallet
    recipient_wallet_id = get_wallet_id_by_address(to_address)
    
    print(f"=== WALLET IDS FOR TRANSACTION LOGGING ===")
    print(f"Admin wallet ID: {admin_wallet_id}")
    print(f"Recipient wallet ID: {recipient_wallet_id}")
    print(f"Authorizer wallet IDs: {[admin_wallet_id] if admin_wallet_id else None}")
    print("==========================================")
    
    # Use Node adapter for transaction execution with wallet IDs
    result = node_adapter.send_transaction(
        transaction_path='cadence/transactions/adminMintBait.cdc',
        args=[to_address, amount],
        roles={'proposer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms'},
        proposer_wallet_id=admin_wallet_id,
        payer_wallet_id=admin_wallet_id,
        authorizer_wallet_ids=[admin_wallet_id] if admin_wallet_id else None
    )
    
    # Check if the transaction actually succeeded
    if not result.get('success'):
        print(f"Admin mint transaction failed: {result.get('stderr', 'Unknown error')}")
        return jsonify({
            'success': False,
            'error': result.get('stderr') or result.get('errorMessage') or 'Transaction failed',
            'stdout': result.get('stdout'),
            'stderr': result.get('stderr'),
            'returncode': result.get('returncode'),
            'transaction_id': result.get('transaction_id'),
            'execution_time': result.get('execution_time')
        }), 400
    
    return jsonify({
        'success': True,
        'stdout': result.get('stdout'),
        'stderr': result.get('stderr'),
        'returncode': result.get('returncode'),
        'transaction_id': result.get('transaction_id'),
        'execution_time': result.get('execution_time')
    })

@app.route('/transactions/check-contract-usdf-balance')
@require_auth
def check_contract_usdf_balance():
    """Check contract USDF balance"""
    network = request.args.get('network', 'mainnet')
    
    # Use Node adapter for transaction execution
    result = node_adapter.send_transaction(
        transaction_path='cadence/transactions/checkContractUsdfBalance.cdc',
        args=[],
        roles={'proposer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms'}
    )
    
    # Check if the transaction actually succeeded
    if not result.get('success'):
        print(f"Check contract balance transaction failed: {result.get('stderr', 'Unknown error')}")
        return jsonify({
            'success': False,
            'error': result.get('stderr') or result.get('errorMessage') or 'Transaction failed',
            'stdout': result.get('stdout'),
            'stderr': result.get('stderr'),
            'returncode': result.get('returncode'),
            'transaction_id': result.get('transaction_id'),
            'execution_time': result.get('execution_time')
        }), 400
    
    return jsonify({
        'success': True,
        'stdout': result.get('stdout'),
        'stderr': result.get('stderr'),
        'returncode': result.get('returncode'),
        'transaction_id': result.get('transaction_id'),
        'execution_time': result.get('execution_time')
    })

def check_bait_balance(flow_address):
    """Check BaitCoin balance for a wallet using checkBaitBalance.cdc script"""
    try:
        # Ensure address has 0x prefix
        if not flow_address.startswith('0x'):
            flow_address = '0x' + flow_address
        
        # Use Node adapter to execute script
        result = node_adapter.execute_script(
            script_path="cadence/scripts/checkBaitBalance.cdc",
            args=[flow_address],
            network="mainnet"
        )
        
        if not result.get('success', False):
            error_msg = result.get('error_message', '') or result.get('stderr', '')
            print(f"Error checking BaitCoin balance for {flow_address}: {error_msg}")
            return None
        
        # Parse the balance from the result
        try:
            balance_data = result.get('data', {})
            if "value" in balance_data:
                balance_str = balance_data["value"]
                balance = float(balance_str)
                return balance
            else:
                print(f"Unexpected response format for {flow_address}: {balance_data}")
                return None
                
        except (ValueError, KeyError, TypeError) as e:
            print(f"Error parsing BaitCoin balance result for {flow_address}: {e}")
            return None
        
    except Exception as e:
        print(f"Error checking BaitCoin balance for {flow_address}: {e}")
        return None

@app.route('/transactions/send-bait', methods=['POST'])
@require_auth
def send_bait():
    """Send BAIT tokens"""
    data = request.get_json() or {}
    to_address = data.get('to_address')
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    
    if not amount:
        return jsonify({'error': 'amount parameter is required'}), 400
    
    if not to_address:
        return jsonify({'error': 'to_address parameter is required'}), 400
    
    # Check if to_address is a user ID (UUID format) and convert to Flow address
    import re
    uuid_pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if re.match(uuid_pattern, to_address):
        print(f"to_address appears to be a user ID: {to_address}")
        flow_address = get_flow_address_by_user_id(to_address)
        if flow_address:
            print(f"Found Flow address for user ID: {flow_address}")
            # Ensure Flow address has 0x prefix
            if not flow_address.startswith('0x'):
                flow_address = f'0x{flow_address}'
            to_address = flow_address
        else:
            return jsonify({'error': f'No wallet found for user ID: {to_address}'}), 404
    else:
        # If it's already a Flow address, ensure it has 0x prefix
        if not to_address.startswith('0x') and len(to_address) == 16:
            to_address = f'0x{to_address}'
    
    # Get user ID for Flow account name (this matches the account name in flow-production.json)
    user_id = request.user_payload.get('sub')
    if not user_id:
        return jsonify({'error': 'No user ID found in token'}), 400
    
    # Debug logging
    print(f"=== PYTHON APP SEND BAIT TRANSACTION ===")
    # Get the user's Flow address for the transaction roles
    user_flow_address = get_wallet_address(request.wallet_details)
    if not user_flow_address:
        return jsonify({'error': 'No Flow address found for authenticated user'}), 400
    
    # Check user's BaitCoin balance before attempting transaction
    print(f"Checking BaitCoin balance for user {user_flow_address}...")
    user_balance = check_bait_balance(user_flow_address)
    
    # Convert amount to float for comparison
    try:
        amount_float = float(amount)
    except (ValueError, TypeError):
        return jsonify({'error': 'Invalid amount format'}), 400
    
    # If balance check failed, log warning but continue with transaction
    if user_balance is None:
        print(f"⚠️  Could not check BaitCoin balance for {user_flow_address}, proceeding with transaction")
        print(f"⚠️  Transaction may fail if insufficient balance")
    else:
        print(f"✓ BaitCoin balance check: {user_balance} BaitCoin")
        
        if user_balance < amount_float:
            return jsonify({
                'error': f'Insufficient BaitCoin balance. You have {user_balance} BaitCoin but are trying to send {amount_float} BaitCoin.',
                'current_balance': user_balance,
                'requested_amount': amount_float,
                'shortfall': amount_float - user_balance
            }), 400
        
        print(f"✓ BaitCoin balance check passed: {user_balance} >= {amount_float}")
    
    print(f"User ID (auth_id): {user_id}")
    print(f"User Flow Address: {user_flow_address}")
    print(f"To address: {to_address}")
    print(f"Amount: {amount_float}")
    print(f"Network: {network}")
    print(f"Wallet Details: {request.wallet_details}")
    print(f"Has Private Key: {bool(user_private_key)}")
    print(f"Roles: proposer={user_id}, authorizer=[{user_id}], payer=mainnet-agfarms")
    print(f"Transaction Path: cadence/transactions/sendBait.cdc")
    print(f"Transaction Args: [{to_address}, {amount_float}]")
    print("=====================================")
    
    # Get wallet IDs for transaction logging
    sender_wallet_id = request.wallet_details.get('id') if request.wallet_details else None
    recipient_wallet_id = get_wallet_id_by_address(to_address)
    admin_wallet_id = get_or_create_admin_wallet()  # Admin wallet for payer
    
    # Get the user's private key from wallet details
    user_private_key = request.wallet_details.get('flow_private_key') if request.wallet_details else None
    if not user_private_key:
        return jsonify({'error': 'No private key found for authenticated user'}), 400
    
    # Use Node adapter for transaction execution with private keys
    # Use auth_id as proposer and authorizer (account name in flow-production.json), mainnet-agfarms as payer
    # Pass amount as decimal (float) to match Flow CLI behavior
    result = node_adapter.send_transaction_with_private_key(
        transaction_path='cadence/transactions/sendBait.cdc',
        args=[to_address, amount_float],  # Use amount_float instead of amount string
        roles={'proposer': user_id, 'authorizer': [user_id], 'payer': 'mainnet-agfarms'},
        private_keys={user_id: user_private_key},  # Pass the private key for the user's auth_id
        proposer_wallet_id=sender_wallet_id,
        payer_wallet_id=admin_wallet_id,
        authorizer_wallet_ids=[sender_wallet_id] if sender_wallet_id else None
    )
    
    print(f"=== PYTHON APP SEND BAIT RESULT ===")
    print(f"Result: {result}")
    print("=====================================")
    
    # Check if the transaction actually succeeded
    if not result.get('success'):
        error_msg = result.get('stderr') or result.get('errorMessage') or 'Transaction failed'
        print(f"Transaction failed: {error_msg}")
        
        # Check for specific insufficient balance error
        if "Cannot withdraw tokens" in error_msg and "greater than the balance" in error_msg:
            return jsonify({
                'success': False,
                'error': 'Insufficient BaitCoin balance. The transaction failed because you do not have enough BaitCoin tokens.',
                'error_type': 'insufficient_balance',
                'stdout': result.get('stdout'),
                'stderr': result.get('stderr'),
                'returncode': result.get('returncode'),
                'transaction_id': result.get('transaction_id'),
                'execution_time': result.get('execution_time')
            }), 400
        
        return jsonify({
            'success': False,
            'error': error_msg,
            'stdout': result.get('stdout'),
            'stderr': result.get('stderr'),
            'returncode': result.get('returncode'),
            'transaction_id': result.get('transaction_id'),
            'execution_time': result.get('execution_time')
        }), 400
    
    return jsonify({
        'success': True,
        'stdout': result.get('stdout'),
        'stderr': result.get('stderr'),
        'returncode': result.get('returncode'),
        'transaction_id': result.get('transaction_id'),
        'execution_time': result.get('execution_time')
    })


# Background task endpoints
@app.route('/background/run-script', methods=['POST'])
@require_auth
def run_script_background():
    """Run a script in the background"""
    data = request.get_json() or {}
    script_name = data.get('script_name')
    args = data.get('args', [])
    network = data.get('network', 'mainnet')
    
    if not script_name:
        return jsonify({'error': 'script_name parameter is required'}), 400
    
    task_id = str(uuid.uuid4())
    start_time = datetime.now().isoformat()
    
    # Store in memory
    background_tasks[task_id] = {
        'status': 'running',
        'start_time': start_time,
        'script_name': script_name,
        'args': args,
        'network': network
    }
    
    
    # Start background thread
    thread = threading.Thread(
        target=run_background_task,
        args=(task_id, f'script execute cadence/scripts/{script_name}', args, network, 'script')
    )
    thread.start()
    
    return jsonify({
        'task_id': task_id,
        'status': 'started',
        'message': f'Script {script_name} started in background'
    })

@app.route('/background/run-transaction', methods=['POST'])
@require_auth
def run_transaction_background():
    """Run a transaction in the background"""
    data = request.get_json() or {}
    transaction_name = data.get('transaction_name')
    args = data.get('args', [])
    network = data.get('network', 'mainnet')
    
    if not transaction_name:
        return jsonify({'error': 'transaction_name parameter is required'}), 400
    
    # Get user ID for Flow account name
    user_id = request.user_payload.get('sub')
    if not user_id:
        return jsonify({'error': 'No user ID found in token'}), 400
    
    # Add proposer and authorizer to args if not already present
    if '--proposer' not in args:
        args.extend(['--proposer', user_id])
    if '--authorizer' not in args:
        args.extend(['--authorizer', user_id])
    
    task_id = str(uuid.uuid4())
    start_time = datetime.now().isoformat()
    
    # Store in memory
    background_tasks[task_id] = {
        'status': 'running',
        'start_time': start_time,
        'transaction_name': transaction_name,
        'args': args,
        'network': network
    }
    
    
    # Start background thread
    thread = threading.Thread(
        target=run_background_task,
        args=(task_id, f'transactions send cadence/transactions/{transaction_name}', args, network, 'transaction')
    )
    thread.start()
    
    return jsonify({
        'task_id': task_id,
        'status': 'started',
        'message': f'Transaction {transaction_name} started in background'
    })

@app.route('/background/task/<task_id>')
@require_auth
def get_task_status(task_id):
    """Get the status of a background task"""
    if task_id not in background_tasks:
        return jsonify({'error': 'Task not found'}), 404
    
    return jsonify(background_tasks[task_id])

@app.route('/background/tasks')
@require_auth
def list_tasks():
    """List all background tasks"""
    return jsonify({
        'tasks': background_tasks,
        'count': len(background_tasks)
    })


# Health check endpoint
@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'active_tasks': len([t for t in background_tasks.values() if t['status'] == 'running'])
    })

# Metrics endpoint
@app.route('/metrics')
@require_auth
def get_metrics():
    """Get Flow wrapper metrics"""
    return jsonify({
        'flow_metrics': flow_wrapper.get_metrics(),
        'timestamp': datetime.now().isoformat()
    })

# Reset metrics endpoint
@app.route('/metrics/reset', methods=['POST'])
@require_auth
def reset_metrics():
    """Reset Flow wrapper metrics"""
    flow_wrapper.reset_metrics()
    return jsonify({
        'message': 'Metrics reset successfully',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
