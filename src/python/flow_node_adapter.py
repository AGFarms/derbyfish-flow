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
        print(f"=== PYTHON FLOW NODE ADAPTER ===")
        print(f"Command: {command}")
        print(f"Payload: {json.dumps(payload, indent=2)}")
        print(f"TypeScript CLI Path: {self.ts_cli}")
        print(f"Flow Directory: {self.flow_dir}")
        print(f"Repository Root: {self.repo_root}")
        
        if not os.path.exists(self.ts_cli):
            raise RuntimeError('TypeScript CLI not built. Run: npm run build')
        
        payload.setdefault('flowDir', self.flow_dir)
        encoded = base64.b64encode(json.dumps(payload).encode('utf-8')).decode('utf-8')
        
        print(f"Encoded Payload Length: {len(encoded)} characters")
        print(f"Full Command: node {self.ts_cli} {command} --payload={encoded[:100]}...")
        
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
        
        print(f"=== TYPESCRIPT EXECUTION RESULTS ===")
        print(f"Return Code: {proc.returncode}")
        print(f"Execution Time: {elapsed:.3f} seconds")
        print(f"STDOUT Length: {len(stdout)} characters")
        print(f"STDERR Length: {len(stderr)} characters")
        
        if stdout:
            print(f"STDOUT Content: {stdout}")
        else:
            print("STDOUT: (empty)")
            
        if stderr:
            print(f"STDERR Content: {stderr}")
        else:
            print("STDERR: (empty)")
        
        if not stdout:
            result = {
                'success': False,
                'stdout': '',
                'stderr': stderr,
                'returncode': proc.returncode,
                'execution_time': elapsed
            }
            print(f"=== ADAPTER RESULT (NO STDOUT) ===")
            print(f"Result: {json.dumps(result, indent=2)}")
            return result
            
        try:
            data = json.loads(stdout)
            print(f"Parsed JSON Data: {json.dumps(data, indent=2)}")
        except Exception as e:
            print(f"JSON Parse Error: {e}")
            data = {'raw': stdout}
            print(f"Using raw data: {data}")
            
        result = {
            'success': bool(data.get('success', proc.returncode == 0)),
            'stdout': stdout,
            'stderr': stderr,
            'returncode': proc.returncode,
            'data': data.get('data'),
            'transaction_id': data.get('transactionId'),
            'error_message': data.get('errorMessage'),
            'execution_time': elapsed,
            'command': f'node {self.ts_cli} {command}'
        }
        
        print(f"=== ADAPTER FINAL RESULT ===")
        print(f"Result: {json.dumps(result, indent=2)}")
        print("=====================================")
        
        return result

    def execute_script(self, script_path: str, args: Optional[List[Any]] = None, network: str = 'mainnet') -> Dict[str, Any]:
        return self._run('execute-script', {
            'scriptPath': script_path,
            'args': args or [],
            'network': network
        })

    def send_transaction(self, transaction_path: str, args: Optional[List[Any]] = None, roles: Optional[Dict[str, Any]] = None, network: str = 'mainnet') -> Dict[str, Any]:
        return self._run('send-transaction', {
            'transactionPath': transaction_path,
            'args': args or [],
            'roles': roles or {},
            'network': network
        })
    
    def send_transaction_with_private_key(self, transaction_path: str, args: Optional[List[Any]] = None, roles: Optional[Dict[str, Any]] = None, network: str = 'mainnet', private_keys: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
        """Send transaction with private keys for accounts not in flow.json"""
        return self._run('send-transaction', {
            'transactionPath': transaction_path,
            'args': args or [],
            'roles': roles or {},
            'network': network,
            'privateKeys': private_keys or {}
        })

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


