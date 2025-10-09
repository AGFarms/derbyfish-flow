import os
import json
import base64
import subprocess
import time
from typing import Any, Dict, List, Optional

class FlowNodeAdapter:
    def __init__(self, repo_root: Optional[str] = None):
        self.repo_root = repo_root or os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
        self.ts_cli = os.path.join(self.repo_root, 'dist', 'cli.js')
        self.flow_dir = os.path.join(self.repo_root, 'flow')

    def _run(self, command: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        if not os.path.exists(self.ts_cli):
            raise RuntimeError('TypeScript CLI not built. Run: npm run build')
        
        payload.setdefault('flowDir', self.flow_dir)
        encoded = base64.b64encode(json.dumps(payload).encode('utf-8')).decode('utf-8')
        
        started = time.time()
        proc = subprocess.run(
            ['node', self.ts_cli, command, f'--payload={encoded}'],
            cwd=self.repo_root,
            capture_output=True,
            text=True,
            timeout=300
        )
        elapsed = time.time() - started
        
        stdout = (proc.stdout or '').strip()
        stderr = (proc.stderr or '').strip()
        
        if not stdout:
            result = {
                'success': False,
                'stdout': '',
                'stderr': stderr,
                'returncode': proc.returncode,
                'execution_time': elapsed
            }
            return result
            
        # Extract JSON from stdout (it might be mixed with other logs)
        lines = stdout.strip().split('\n')
        json_line = None
        for line in reversed(lines):  # Look for JSON in the last few lines
            line = line.strip()
            if line.startswith('{') and line.endswith('}'):
                try:
                    json.loads(line)  # Test if it's valid JSON
                    json_line = line
                    break
                except json.JSONDecodeError:
                    continue
        
        if not json_line:
            raise RuntimeError(f"No valid JSON found in stdout: {stdout}")
        
        data = json.loads(json_line)
            
        result = {
            'success': data.get('success', False),
            'stdout': stdout,
            'stderr': stderr,
            'returncode': proc.returncode,
            'data': data.get('data'),
            'transaction_id': data.get('transactionId'),
            'error_message': data.get('errorMessage'),
            'execution_time': elapsed,
            'command': f'node {self.ts_cli} {command}'
        }
        
        return result

    def execute_script(self, script_path: str, args: Optional[List[Any]] = None, network: str = 'mainnet') -> Dict[str, Any]:
        return self._run('execute-script', {
            'scriptPath': script_path,
            'args': args or [],
            'network': network
        })

    def send_transaction(self, transaction_path: str, args: Optional[List[Any]] = None, roles: Optional[Dict[str, Any]] = None, network: str = 'mainnet', proposer_wallet_id: Optional[str] = None, payer_wallet_id: Optional[str] = None, authorizer_wallet_ids: Optional[List[str]] = None) -> Dict[str, Any]:
        payload = {
            'transactionPath': transaction_path,
            'args': args or [],
            'roles': roles or {},
            'network': network
        }
        
        # Add wallet IDs if provided
        if proposer_wallet_id:
            payload['proposerWalletId'] = proposer_wallet_id
        if payer_wallet_id:
            payload['payerWalletId'] = payer_wallet_id
        if authorizer_wallet_ids:
            payload['authorizerWalletIds'] = authorizer_wallet_ids
        
            
        return self._run('send-transaction', payload)
    
    def send_transaction_with_private_key(self, transaction_path: str, args: Optional[List[Any]] = None, roles: Optional[Dict[str, Any]] = None, network: str = 'mainnet', private_keys: Optional[Dict[str, str]] = None, proposer_wallet_id: Optional[str] = None, payer_wallet_id: Optional[str] = None, authorizer_wallet_ids: Optional[List[str]] = None) -> Dict[str, Any]:
        """Send transaction with private keys for accounts not in flow.json"""
        payload = {
            'transactionPath': transaction_path,
            'args': args or [],
            'roles': roles or {},
            'network': network,
            'privateKeys': private_keys or {}
        }
        
        # Add wallet IDs if provided
        if proposer_wallet_id:
            payload['proposerWalletId'] = proposer_wallet_id
        if payer_wallet_id:
            payload['payerWalletId'] = payer_wallet_id
        if authorizer_wallet_ids:
            payload['authorizerWalletIds'] = authorizer_wallet_ids
            
        return self._run('send-transaction', payload)

    def get_transaction(self, transaction_id: str, network: str = 'mainnet') -> Dict[str, Any]:
        return self._run('get-transaction', {
            'transactionId': transaction_id,
            'network': network
        })

    def get_account(self, address: str, network: str = 'mainnet') -> Dict[str, Any]:
        return self._run('get-account', {
            'address': address,
            'network': network
        })


