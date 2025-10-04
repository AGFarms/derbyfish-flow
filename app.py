from flask import Flask, request, jsonify
import subprocess
import json
import os
import threading
import time
from datetime import datetime
import uuid

app = Flask(__name__)

# Global storage for background tasks
background_tasks = {}

def run_flow_transaction_with_keys(transaction_file, args, signer_key, network="mainnet"):
    """Execute a Flow transaction using private keys directly"""
    start_time = datetime.now()
    
    try:
        # Change to the flow directory
        flow_dir = os.path.join(os.path.dirname(__file__), 'flow')
        
        # Find the correct Flow binary
        flow_binary = subprocess.run(['which', 'flow'], capture_output=True, text=True).stdout.strip()
        
        # Build the command with private keys
        cmd_parts = [
            flow_binary, 'transactions', 'send', transaction_file,
            '--proposer-key', 'mainnet-agfarms.pkey',
            '--authorizer-key', f'{signer_key}.pkey',
            '--payer', 'mainnet-agfarms',
            '--network', network
        ]
        
        # Add transaction arguments
        if args:
            cmd_parts.extend(args)
        
        # Create the command string
        cmd_str = ' '.join(cmd_parts)
        
        # Debug logging
        print(f"=== DEBUG: Flow Transaction with Keys ===")
        print(f"Command parts: {cmd_parts}")
        print(f"Final command string: {cmd_str}")
        print(f"Working directory: {flow_dir}")
        print(f"Flow binary: {flow_binary}")
        
        # Execute the command from the flow directory
        result = subprocess.run(
            cmd_str,
            cwd=flow_dir,
            capture_output=True,
            text=True,
            shell=True,
            timeout=300  # 5 minute timeout
        )
        
        end_time = datetime.now()
        execution_time = (end_time - start_time).total_seconds()
        
        response = {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode,
            'command': cmd_str,
            'execution_time': execution_time,
            'network': network
        }
        
        return response
    except subprocess.TimeoutExpired:
        end_time = datetime.now()
        execution_time = (end_time - start_time).total_seconds()
        
        response = {
            'success': False,
            'stdout': '',
            'stderr': 'Command timed out after 5 minutes',
            'returncode': -1,
            'command': cmd_str,
            'execution_time': execution_time,
            'network': network
        }
        
        return response
    except Exception as e:
        end_time = datetime.now()
        execution_time = (end_time - start_time).total_seconds()
        
        response = {
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'returncode': -1,
            'command': cmd_str,
            'execution_time': execution_time,
            'network': network
        }
        
        return response

def run_flow_command(command, args=None, network="mainnet"):
    """Execute a Flow CLI command and return the result"""
    start_time = datetime.now()
    
    try:
        # Change to the flow directory
        flow_dir = os.path.join(os.path.dirname(__file__), 'flow')
        
        # Find the correct Flow binary
        flow_binary = subprocess.run(['which', 'flow'], capture_output=True, text=True).stdout.strip()
        
        # Build the command string
        cmd_parts = [flow_binary] + command.split()
        if args:
            cmd_parts.extend(args)


        # Add payer for all transaction commands
        if 'transaction send' in ' '.join(cmd_parts) or 'transactions send' in ' '.join(cmd_parts):
            cmd_parts.extend(['--payer', 'mainnet-agfarms'])

        # Add network flag if not already present
        if '--network' not in cmd_parts and '--net' not in cmd_parts:
            cmd_parts.extend(['--network', network])
        
        # Create the command string
        cmd_str = ' '.join(cmd_parts)
        
        # Debug logging
        print(f"=== DEBUG: Flow Command ===")
        print(f"Command parts: {cmd_parts}")
        print(f"Final command string: {cmd_str}")
        print(f"Working directory: {flow_dir}")
        print(f"Flow binary: {flow_binary}")
        
        # Execute the command from the flow directory
        result = subprocess.run(
            cmd_str,
            cwd=flow_dir,
            capture_output=True,
            text=True,
            shell=True,
            timeout=300  # 5 minute timeout
        )
        
        end_time = datetime.now()
        execution_time = (end_time - start_time).total_seconds()
        
        response = {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode,
            'command': cmd_str,
            'execution_time': execution_time,
            'network': network
        }
        
        return response
    except subprocess.TimeoutExpired:
        end_time = datetime.now()
        execution_time = (end_time - start_time).total_seconds()
        
        response = {
            'success': False,
            'stdout': '',
            'stderr': 'Command timed out after 5 minutes',
            'returncode': -1,
            'command': ' '.join(cmd),
            'execution_time': execution_time,
            'network': network
        }
        
        return response
    except Exception as e:
        end_time = datetime.now()
        execution_time = (end_time - start_time).total_seconds()
        
        response = {
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'returncode': -1,
            'command': ' '.join(cmd),
            'execution_time': execution_time,
            'network': network
        }
        
        return response

def run_background_task(task_id, command, args=None, network="mainnet", task_type="script"):
    """Run a Flow command in the background and store the result"""
    start_time = datetime.now()
    result = run_flow_command(command, args, network)
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

# Script endpoints
@app.route('/scripts/check-bait-balance')
def check_bait_balance():
    """Check BAIT balance for an address"""
    print("=== CHECK BAIT BALANCE ENDPOINT CALLED ===")
    address = request.args.get('address')
    network = request.args.get('network', 'mainnet')
    
    if not address:
        return jsonify({'error': 'Address parameter is required'}), 400
    
    print(f"Address: {address}, Network: {network}")
    
    # Try direct execution first
    import subprocess
    flow_dir = os.path.join(os.path.dirname(__file__), 'flow')
    flow_binary = subprocess.run(['which', 'flow'], capture_output=True, text=True).stdout.strip()
    script_full_path = os.path.join(flow_dir, 'cadence', 'scripts', 'checkBaitBalance.cdc')
    
    cmd_str = f'{flow_binary} scripts execute {script_full_path} {address} --network {network} --output json'
    print(f"Direct command: {cmd_str}")
    
    result = subprocess.run(cmd_str, cwd=flow_dir, capture_output=True, text=True, shell=True)
    
    return jsonify({
        'command': cmd_str,
        'success': result.returncode == 0,
        'stdout': result.stdout,
        'stderr': result.stderr,
        'returncode': result.returncode
    })

@app.route('/scripts/check-contract-vaults')
def check_contract_vaults():
    """Check contract vaults"""
    network = request.args.get('network', 'mainnet')
    
    # Direct execution
    import subprocess
    flow_dir = os.path.join(os.path.dirname(__file__), 'flow')
    flow_binary = subprocess.run(['which', 'flow'], capture_output=True, text=True).stdout.strip()
    script_full_path = os.path.join(flow_dir, 'cadence', 'scripts', 'checkContractVaults.cdc')
    
    cmd_str = f'{flow_binary} scripts execute {script_full_path} --network {network} --output json'
    
    result = subprocess.run(cmd_str, cwd=flow_dir, capture_output=True, text=True, shell=True)
    
    return jsonify({
        'command': cmd_str,
        'success': result.returncode == 0,
        'stdout': result.stdout,
        'stderr': result.stderr,
        'returncode': result.returncode
    })

@app.route('/scripts/create-vault-and-mint', methods=['POST'])
def create_vault_and_mint():
    """Create vault and mint tokens"""
    data = request.get_json() or {}
    network = data.get('network', 'mainnet')
    
    result = run_flow_command(f'script execute cadence/scripts/createVaultAndMint.cdc', [], network)
    return jsonify(result)

@app.route('/scripts/sell-bait', methods=['POST'])
def sell_bait():
    """Sell BAIT tokens"""
    data = request.get_json() or {}
    network = data.get('network', 'mainnet')
    
    result = run_flow_command(f'script execute cadence/scripts/sellBait.cdc', [], network)
    return jsonify(result)

@app.route('/scripts/test-bait-coin-admin', methods=['POST'])
def test_bait_coin_admin():
    """Test BAIT coin admin functions"""
    data = request.get_json() or {}
    network = data.get('network', 'mainnet')
    
    result = run_flow_command(f'script execute cadence/scripts/testBaitCoinAdmin.cdc', [], network)
    return jsonify(result)

# Transaction endpoints
@app.route('/transactions/admin-burn-bait', methods=['POST'])
def admin_burn_bait():
    """Admin burn BAIT tokens"""
    data = request.get_json() or {}
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    args = [amount, '--proposer', 'mainnet-agfarms', '--authorizer', signer]
    result = run_flow_command(f'transactions send cadence/transactions/adminBurnBait.cdc', args, network)
    return jsonify(result)

@app.route('/transactions/admin-mint-bait', methods=['POST'])
def admin_mint_bait():
    """Admin mint BAIT tokens"""
    data = request.get_json() or {}
    amount = data.get('amount')
    to_address = data.get('to_address')
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    if not to_address:
        return jsonify({'error': 'to_address parameter is required'}), 400
    
    # Direct execution
    import subprocess
    flow_dir = os.path.join(os.path.dirname(__file__), 'flow')
    flow_binary = subprocess.run(['which', 'flow'], capture_output=True, text=True).stdout.strip()
    script_full_path = os.path.join(flow_dir, 'cadence', 'transactions', 'adminMintBait.cdc')
    
    cmd_str = f'{flow_binary} transactions send {script_full_path} {to_address} {amount} --proposer mainnet-agfarms --authorizer {signer} --payer mainnet-agfarms --network {network}'
    
    result = subprocess.run(cmd_str, cwd=flow_dir, capture_output=True, text=True, shell=True)
    
    return jsonify({
        'command': cmd_str,
        'success': result.returncode == 0,
        'stdout': result.stdout,
        'stderr': result.stderr,
        'returncode': result.returncode,
        'execution_time': 0  # You can add timing if needed
    })

@app.route('/transactions/admin-mint-fusd', methods=['POST'])
def admin_mint_fusd():
    """Admin mint FUSD tokens"""
    data = request.get_json() or {}
    amount = data.get('amount')
    to_address = data.get('to_address')
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    if not to_address:
        return jsonify({'error': 'to_address parameter is required'}), 400
    
    args = [to_address, amount, '--proposer', 'mainnet-agfarms', '--authorizer', signer]
    result = run_flow_command(f'transactions send cadence/transactions/adminMintFusd.cdc', args, network)
    return jsonify(result)

@app.route('/transactions/check-contract-usdf-balance')
def check_contract_usdf_balance():
    """Check contract USDF balance"""
    network = request.args.get('network', 'mainnet')
    signer = request.args.get('signer', 'mainnet-agfarms')
    
    args = ['--proposer', 'mainnet-agfarms', '--authorizer', signer]
    result = run_flow_command(f'transactions send cadence/transactions/checkContractUsdfBalance.cdc', args, network)
    return jsonify(result)

@app.route('/transactions/create-all-vault', methods=['POST'])
def create_all_vault():
    """Create all vaults"""
    data = request.get_json() or {}
    address = data.get('address')
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not address:
        return jsonify({'error': 'address parameter is required'}), 400
    
    args = [address]
    result = run_flow_transaction_with_keys('cadence/transactions/createAllVault.cdc', args, signer, network)
    return jsonify(result)

@app.route('/transactions/create-usdf-vault', methods=['POST'])
def create_usdf_vault():
    """Create USDF vault"""
    data = request.get_json() or {}
    address = data.get('address')
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not address:
        return jsonify({'error': 'address parameter is required'}), 400
    
    args = [address, '--proposer', 'mainnet-agfarms', '--authorizer', signer]
    result = run_flow_command(f'transactions send cadence/transactions/createUsdfVault.cdc', args, network)
    return jsonify(result)

@app.route('/transactions/reset-all-vaults', methods=['POST'])
def reset_all_vaults():
    """Reset all vaults"""
    data = request.get_json() or {}
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    args = ['--proposer', 'mainnet-agfarms', '--authorizer', signer]
    result = run_flow_command(f'transactions send cadence/transactions/resetAllVaults.cdc', args, network)
    return jsonify(result)

@app.route('/transactions/send-bait', methods=['POST'])
def send_bait():
    """Send BAIT tokens"""
    data = request.get_json() or {}
    to_address = data.get('to_address')
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not to_address or not amount:
        return jsonify({'error': 'to_address and amount parameters are required'}), 400
    
    args = [to_address, amount, '--proposer', 'mainnet-agfarms', '--authorizer', signer]
    result = run_flow_command(f'transactions send cadence/transactions/sendBait.cdc', args, network)
    return jsonify(result)

@app.route('/transactions/send-fusd', methods=['POST'])
def send_fusd():
    """Send FUSD tokens"""
    data = request.get_json() or {}
    to_address = data.get('to_address')
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not to_address or not amount:
        return jsonify({'error': 'to_address and amount parameters are required'}), 400
    
    args = [to_address, amount, '--proposer', 'mainnet-agfarms', '--authorizer', signer]
    result = run_flow_command(f'transactions send cadence/transactions/sendFusd.cdc', args, network)
    return jsonify(result)

@app.route('/transactions/swap-bait-for-fusd', methods=['POST'])
def swap_bait_for_fusd():
    """Swap BAIT for FUSD"""
    data = request.get_json() or {}
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    args = [amount, '--proposer', 'mainnet-agfarms', '--authorizer', signer]
    result = run_flow_command(f'transactions send cadence/transactions/swapBaitForFusd.cdc', args, network)
    return jsonify(result)

@app.route('/transactions/swap-fusd-for-bait', methods=['POST'])
def swap_fusd_for_bait():
    """Swap FUSD for BAIT"""
    data = request.get_json() or {}
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    args = [amount, '--proposer', 'mainnet-agfarms', '--authorizer', signer]
    result = run_flow_command(f'transactions send cadence/transactions/swapFusdForBait.cdc', args, network)
    return jsonify(result)

@app.route('/transactions/withdraw-contract-usdf', methods=['POST'])
def withdraw_contract_usdf():
    """Withdraw contract USDF"""
    data = request.get_json() or {}
    amount = data.get('amount')
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not amount:
        return jsonify({'error': 'Amount parameter is required'}), 400
    
    args = [amount, '--proposer', 'mainnet-agfarms', '--authorizer', signer]
    result = run_flow_command(f'transactions send cadence/transactions/withdrawContractUsdf.cdc', args, network)
    return jsonify(result)

@app.route('/transactions/deposit-flow', methods=['POST'])
def deposit_flow():
    """Deposit FLOW tokens to an account for storage capacity"""
    data = request.get_json() or {}
    to_address = data.get('to_address')
    amount = data.get('amount', '0.25')  # Default 0.25 FLOW
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not to_address:
        return jsonify({'error': 'to_address parameter is required'}), 400
    
    # Use Flow CLI to send FLOW tokens
    import subprocess
    flow_dir = os.path.join(os.path.dirname(__file__), 'flow')
    flow_binary = subprocess.run(['which', 'flow'], capture_output=True, text=True).stdout.strip()
    
    cmd_str = f'{flow_binary} transactions send --code "import FlowToken from 0x7e60df042a9c0868; transaction(recipient: Address, amount: UFix64) {{ prepare(signer: auth(BorrowValue, Storage) &Account) {{ let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault) ?? panic(\"Could not borrow FlowToken vault\"); let tokens <- vault.withdraw(amount: amount); let recipient = getAccount(recipient); let receiver = recipient.capabilities.get<&{{FungibleToken.Receiver}}>(/public/flowTokenReceiver) ?? panic(\"Could not borrow FlowToken receiver\"); receiver.deposit(from: <-tokens); }} execute {{ log(\"Transferred \".concat(amount.toString()).concat(\" FLOW tokens\").concat(\" to \").concat(recipient.toString())); }}" --arg "Address:0x{to_address}" --arg "UFix64:{amount}" --proposer mainnet-agfarms --authorizer {signer} --payer mainnet-agfarms --network {network}'
    
    result = subprocess.run(cmd_str, cwd=flow_dir, capture_output=True, text=True, shell=True)
    
    return jsonify({
        'command': cmd_str,
        'success': result.returncode == 0,
        'stdout': result.stdout,
        'stderr': result.stderr,
        'returncode': result.returncode
    })

# Background task endpoints
@app.route('/background/run-script', methods=['POST'])
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
def run_transaction_background():
    """Run a transaction in the background"""
    data = request.get_json() or {}
    transaction_name = data.get('transaction_name')
    args = data.get('args', [])
    network = data.get('network', 'mainnet')
    signer = data.get('signer', 'mainnet-agfarms')
    
    if not transaction_name:
        return jsonify({'error': 'transaction_name parameter is required'}), 400
    
    # Add proposer and authorizer to args if not already present
    if '--proposer' not in args:
        args.extend(['--proposer', 'mainnet-agfarms'])
    if '--authorizer' not in args:
        args.extend(['--authorizer', signer])
    
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
def get_task_status(task_id):
    """Get the status of a background task"""
    if task_id not in background_tasks:
        return jsonify({'error': 'Task not found'}), 404
    
    return jsonify(background_tasks[task_id])

@app.route('/background/tasks')
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

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
