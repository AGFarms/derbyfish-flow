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
from flowWrapper import FlowWrapper, FlowConfig, FlowNetwork, FlowResult

# Load environment variables
load_dotenv()

app = Flask(__name__)

# Supabase configuration
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_ANON_KEY = os.getenv('SUPABASE_ANON_KEY')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
SUPABASE_JWT_SECRET = os.getenv('SUPABASE_JWT_SECRET')

# Validate required environment variables
if not SUPABASE_URL:
    print("WARNING: SUPABASE_URL environment variable not set")
if not SUPABASE_ANON_KEY:
    print("WARNING: SUPABASE_ANON_KEY environment variable not set")
if not SUPABASE_SERVICE_KEY:
    print("WARNING: SUPABASE_SERVICE_ROLE_KEY environment variable not set - server-side operations may not work")
if not SUPABASE_JWT_SECRET:
    print("WARNING: SUPABASE_JWT_SECRET environment variable not set - JWT authentication will not work")

# Initialize Supabase client with service role key for server-side operations
# This bypasses RLS policies for server-side wallet lookups
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY) if SUPABASE_URL and SUPABASE_SERVICE_KEY else None

# Global storage for background tasks
background_tasks = {}

# Initialize Flow wrapper
flow_wrapper = FlowWrapper(FlowConfig(
    network=FlowNetwork.MAINNET,
    flow_dir=os.path.join(os.path.dirname(__file__), 'flow'),
    timeout=300,
    max_retries=3,
    rate_limit_delay=0.2,
    json_output=True
))

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
                'admin_burn_bait': 'POST /transactions/admin-burn-bait (amount)',
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
    
    # Use Flow wrapper for script execution
    result = flow_wrapper.execute_script(
        script_path='cadence/scripts/checkBaitBalance.cdc',
        args=[address]
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'data': result.data,
        'execution_time': result.execution_time
    })

@app.route('/scripts/check-contract-vaults')
@require_auth
def check_contract_vaults():
    """Check contract vaults"""
    network = request.args.get('network', 'mainnet')
    
    # Use Flow wrapper for script execution
    result = flow_wrapper.execute_script(
        script_path='cadence/scripts/checkContractVaults.cdc'
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'data': result.data,
        'execution_time': result.execution_time
    })

@app.route('/scripts/create-vault-and-mint', methods=['POST'])
@require_auth
def create_vault_and_mint():
    """Create vault and mint tokens"""
    data = request.get_json() or {}
    network = data.get('network', 'mainnet')
    
    # Use Flow wrapper for script execution
    result = flow_wrapper.execute_script(
        script_path='cadence/scripts/createVaultAndMint.cdc'
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'data': result.data,
        'execution_time': result.execution_time
    })

@app.route('/scripts/sell-bait', methods=['POST'])
@require_auth
def sell_bait():
    """Sell BAIT tokens"""
    data = request.get_json() or {}
    network = data.get('network', 'mainnet')
    
    # Use Flow wrapper for script execution
    result = flow_wrapper.execute_script(
        script_path='cadence/scripts/sellBait.cdc'
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'data': result.data,
        'execution_time': result.execution_time
    })

@app.route('/scripts/test-bait-coin-admin', methods=['POST'])
@require_auth
def test_bait_coin_admin():
    """Test BAIT coin admin functions"""
    data = request.get_json() or {}
    network = data.get('network', 'mainnet')
    
    # Use Flow wrapper for script execution
    result = flow_wrapper.execute_script(
        script_path='cadence/scripts/testBaitCoinAdmin.cdc'
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'data': result.data,
        'execution_time': result.execution_time
    })

# Transaction endpoints
@app.route('/transactions/admin-burn-bait', methods=['POST'])
@require_auth
def admin_burn_bait():
    """Admin burn BAIT tokens"""
    data = request.get_json() or {}
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/adminBurnBait.cdc',
        args=[amount],
        proposer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
        authorizer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
        payer='mainnet-agfarms'  # Admin operation - use mainnet-agfarms
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/admin-mint-bait', methods=['POST'])
@require_auth
def admin_mint_bait():
    """Admin mint BAIT tokens"""
    data = request.get_json() or {}
    amount = data.get('amount')
    to_address = data.get('to_address')
    network = data.get('network', 'mainnet')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    # Use authenticated user's wallet address as default if not specified
    if not to_address:
        to_address = get_wallet_address(request.wallet_details)
        if to_address:
            print(f"Using authenticated user's wallet address: {to_address}")
        else:
            return jsonify({'error': 'to_address parameter is required and no wallet address found for authenticated user'}), 400
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/adminMintBait.cdc',
        args=[to_address, amount],
        proposer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
        authorizer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
        payer='mainnet-agfarms'  # Admin operation - use mainnet-agfarms
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/admin-mint-fusd', methods=['POST'])
@require_auth
def admin_mint_fusd():
    """Admin mint FUSD tokens"""
    data = request.get_json() or {}
    amount = data.get('amount')
    to_address = data.get('to_address')
    network = data.get('network', 'mainnet')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    # Use authenticated user's wallet address as default if not specified
    if not to_address:
        to_address = get_wallet_address(request.wallet_details)
        if to_address:
            print(f"Using authenticated user's wallet address: {to_address}")
        else:
            return jsonify({'error': 'to_address parameter is required and no wallet address found for authenticated user'}), 400
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/adminMintFusd.cdc',
        args=[to_address, amount],
        proposer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
        authorizer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
        payer='mainnet-agfarms'  # Admin operation - use mainnet-agfarms
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/check-contract-usdf-balance')
@require_auth
def check_contract_usdf_balance():
    """Check contract USDF balance"""
    network = request.args.get('network', 'mainnet')
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/checkContractUsdfBalance.cdc',
        args=[],
        proposer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
        authorizer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
        payer='mainnet-agfarms'  # Admin operation - use mainnet-agfarms
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/create-all-vault', methods=['POST'])
@require_auth
def create_all_vault():
    """Create all vaults"""
    data = request.get_json() or {}
    address = data.get('address')
    network = data.get('network', 'mainnet')
    
    # Use authenticated user's wallet address as default if not specified
    if not address:
        address = get_wallet_address(request.wallet_details)
        if address:
            print(f"Using authenticated user's wallet address: {address}")
        else:
            return jsonify({'error': 'address parameter is required and no wallet address found for authenticated user'}), 400
    
    # Get user ID for Flow account name
    user_id = request.user_payload.get('sub')
    if not user_id:
        return jsonify({'error': 'No user ID found in token'}), 400
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/createAllVault.cdc',
        args=[address],
        proposer='mainnet-agfarms',  # Hardcoded to mainnet-agfarms
        authorizers=[user_id],  # Use user ID as additional authorizer (mainnet-agfarms is always included)
        payer='mainnet-agfarms'  # Always use mainnet-agfarms as payer
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/create-usdf-vault', methods=['POST'])
@require_auth
def create_usdf_vault():
    """Create USDF vault"""
    data = request.get_json() or {}
    address = data.get('address')
    network = data.get('network', 'mainnet')
    
    # Use authenticated user's wallet address as default if not specified
    if not address:
        address = get_wallet_address(request.wallet_details)
        if address:
            print(f"Using authenticated user's wallet address: {address}")
        else:
            return jsonify({'error': 'address parameter is required and no wallet address found for authenticated user'}), 400
    
    # Get user ID for Flow account name
    user_id = request.user_payload.get('sub')
    if not user_id:
        return jsonify({'error': 'No user ID found in token'}), 400
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/createUsdfVault.cdc',
        args=[address],
        proposer='mainnet-agfarms',  # Hardcoded to mainnet-agfarms
        authorizers=[user_id],  # Use user ID as additional authorizer (mainnet-agfarms is always included)
        payer='mainnet-agfarms'  # Always use mainnet-agfarms as payer
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/reset-all-vaults', methods=['POST'])
@require_auth
def reset_all_vaults():
    """Reset all vaults"""
    data = request.get_json() or {}
    network = data.get('network', 'mainnet')
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/resetAllVaults.cdc',
        args=[],
        proposer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
        authorizer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
        payer='mainnet-agfarms'  # Admin operation - use mainnet-agfarms
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

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
    
    # Use authenticated user's wallet address as default if not specified
    if not to_address:
        to_address = get_wallet_address(request.wallet_details)
        if to_address:
            print(f"Using authenticated user's wallet address: {to_address}")
        else:
            return jsonify({'error': 'to_address parameter is required and no wallet address found for authenticated user'}), 400
    
    # Get user ID for Flow account name
    user_id = request.user_payload.get('sub')
    if not user_id:
        return jsonify({'error': 'No user ID found in token'}), 400
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/sendBait.cdc',
        args=[to_address, amount],
        proposer='mainnet-agfarms',  # Hardcoded to mainnet-agfarms
        authorizers=[user_id],  # Use user ID as additional authorizer (mainnet-agfarms is always included)
        payer='mainnet-agfarms'  # Always use mainnet-agfarms as payer
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/send-fusd', methods=['POST'])
@require_auth
def send_fusd():
    """Send FUSD tokens"""
    data = request.get_json() or {}
    to_address = data.get('to_address')
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    
    if not amount:
        return jsonify({'error': 'amount parameter is required'}), 400
    
    # Use authenticated user's wallet address as default if not specified
    if not to_address:
        to_address = get_wallet_address(request.wallet_details)
        if to_address:
            print(f"Using authenticated user's wallet address: {to_address}")
        else:
            return jsonify({'error': 'to_address parameter is required and no wallet address found for authenticated user'}), 400
    
    # Get user ID for Flow account name
    user_id = request.user_payload.get('sub')
    if not user_id:
        return jsonify({'error': 'No user ID found in token'}), 400
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/sendFusd.cdc',
        args=[to_address, amount],
        proposer='mainnet-agfarms',  # Hardcoded to mainnet-agfarms
        authorizers=[user_id],  # Use user ID as additional authorizer (mainnet-agfarms is always included)
        payer='mainnet-agfarms'  # Always use mainnet-agfarms as payer
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/swap-bait-for-fusd', methods=['POST'])
@require_auth
def swap_bait_for_fusd():
    """Swap BAIT for FUSD"""
    data = request.get_json() or {}
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    # Get user ID for Flow account name
    user_id = request.user_payload.get('sub')
    if not user_id:
        return jsonify({'error': 'No user ID found in token'}), 400
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/swapBaitForFusd.cdc',
        args=[amount],
        proposer='mainnet-agfarms',  # Hardcoded to mainnet-agfarms
        authorizers=[user_id],  # Use user ID as additional authorizer (mainnet-agfarms is always included)
        payer='mainnet-agfarms'  # Always use mainnet-agfarms as payer
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/swap-fusd-for-bait', methods=['POST'])
@require_auth
def swap_fusd_for_bait():
    """Swap FUSD for BAIT"""
    data = request.get_json() or {}
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    # Get user ID for Flow account name
    user_id = request.user_payload.get('sub')
    if not user_id:
        return jsonify({'error': 'No user ID found in token'}), 400
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/swapFusdForBait.cdc',
        args=[amount],
        proposer='mainnet-agfarms',  # Hardcoded to mainnet-agfarms
        authorizers=[user_id],  # Use user ID as additional authorizer (mainnet-agfarms is always included)
        payer='mainnet-agfarms'  # Always use mainnet-agfarms as payer
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/withdraw-contract-usdf', methods=['POST'])
@require_auth
def withdraw_contract_usdf():
    """Withdraw contract USDF"""
    data = request.get_json() or {}
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    # Get user ID for Flow account name
    user_id = request.user_payload.get('sub')
    if not user_id:
        return jsonify({'error': 'No user ID found in token'}), 400
    
    # Use Flow wrapper for transaction execution
    result = flow_wrapper.send_transaction(
        transaction_path='cadence/transactions/withdrawContractUsdf.cdc',
        args=[amount],
        proposer='mainnet-agfarms',  # Hardcoded to mainnet-agfarms
        authorizers=[user_id],  # Use user ID as additional authorizer (mainnet-agfarms is always included)
        payer='mainnet-agfarms'  # Always use mainnet-agfarms as payer
    )
    
    return jsonify({
        'command': result.command,
        'success': result.success,
        'stdout': result.raw_output,
        'stderr': result.error_message,
        'returncode': 0 if result.success else 1,
        'transaction_id': result.transaction_id,
        'execution_time': result.execution_time
    })

@app.route('/transactions/deposit-flow', methods=['POST'])
@require_auth
def deposit_flow():
    """Deposit FLOW tokens to an account for storage capacity"""
    data = request.get_json() or {}
    to_address = data.get('to_address')
    amount = data.get('amount', '0.25')  # Default 0.25 FLOW
    network = data.get('network', 'mainnet')
    
    # Use authenticated user's wallet address as default if not specified
    if not to_address:
        to_address = get_wallet_address(request.wallet_details)
        if to_address:
            print(f"Using authenticated user's wallet address: {to_address}")
        else:
            return jsonify({'error': 'to_address parameter is required and no wallet address found for authenticated user'}), 400
    
    # Use Flow wrapper for transaction execution with inline code
    try:
        # Create a temporary transaction file for the inline code
        inline_code = f'''import FlowToken from 0x7e60df042a9c0868

transaction(recipient: Address, amount: UFix64) {{
    prepare(signer: auth(BorrowValue, Storage) &Account) {{
        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault) 
            ?? panic("Could not borrow FlowToken vault")
        let tokens <- vault.withdraw(amount: amount)
        let recipient = getAccount(recipient)
        let receiver = recipient.capabilities.get<&{{FungibleToken.Receiver}}>(/public/flowTokenReceiver) 
            ?? panic("Could not borrow FlowToken receiver")
        receiver.deposit(from: <-tokens)
    }}
    execute {{
        log("Transferred ".concat(amount.toString()).concat(" FLOW tokens").concat(" to ").concat(recipient.toString()))
    }}
}}'''
        
        # Write temporary transaction file
        temp_tx_path = os.path.join(flow_wrapper.config.flow_dir, 'temp_deposit_flow.cdc')
        with open(temp_tx_path, 'w') as f:
            f.write(inline_code)
        
        # Execute transaction
        result = flow_wrapper.send_transaction(
            transaction_path='temp_deposit_flow.cdc',
            args=[f'0x{to_address}', amount],
            proposer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
            authorizer='mainnet-agfarms',  # Admin operation - use mainnet-agfarms
            payer='mainnet-agfarms'  # Admin operation - use mainnet-agfarms
        )
        
        # Clean up temporary file
        try:
            os.remove(temp_tx_path)
        except:
            pass
        
        return jsonify({
            'command': result.command,
            'success': result.success,
            'stdout': result.raw_output,
            'stderr': result.error_message,
            'returncode': 0 if result.success else 1,
            'transaction_id': result.transaction_id,
            'execution_time': result.execution_time
        })
        
    except Exception as e:
        return jsonify({
            'command': 'deposit-flow transaction',
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'returncode': -1
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
