import os
import json
import asyncio
import time
from typing import Any, Dict, List, Optional

from flow_py_sdk import flow_client
from flow_py_sdk.account_key import AccountKey
from flow_py_sdk.script import Script
from flow_py_sdk.tx import Tx, ProposalKey
from flow_py_sdk.signer import InMemorySigner, HashAlgo, SignAlgo
from flow_py_sdk.cadence import Address, Array, String, UFix64, UInt8, Value

UFIX64_FACTOR = 100_000_000


def _get_access_node(network: str) -> tuple[str, int]:
    if network == 'mainnet':
        return ('access.mainnet.nodes.onflow.org', 9000)
    if network == 'testnet':
        return ('access.devnet.nodes.onflow.org', 9000)
    return ('127.0.0.1', 3569)


def _to_cadence_arg(arg: Any) -> Value:
    if isinstance(arg, Value):
        return arg
    if isinstance(arg, (bytes, bytearray)):
        return Array([UInt8(b) for b in arg])
    if isinstance(arg, str):
        if arg.startswith('0x') or (len(arg) == 16 and all(c in '0123456789abcdefABCDEF' for c in arg)):
            return Address.from_hex(arg if arg.startswith('0x') else f'0x{arg}')
        if '.' in arg and arg.replace('.', '').replace('-', '').isdigit():
            try:
                val = float(arg)
                return UFix64(int(val * UFIX64_FACTOR))
            except (ValueError, TypeError):
                pass
        return String(arg)
    if isinstance(arg, (int, float)):
        val = float(arg) if isinstance(arg, int) else arg
        return UFix64(int(val * UFIX64_FACTOR))
    return String(str(arg))


class FlowPyAdapter:
    def __init__(self, repo_root: Optional[str] = None):
        self.repo_root = repo_root or os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
        self.flow_dir = os.path.join(self.repo_root, 'flow')
        self._service_account: Optional[Dict[str, Any]] = None
        self._tx_lock: Optional[asyncio.Lock] = None

    def _get_tx_lock(self) -> asyncio.Lock:
        if self._tx_lock is None:
            self._tx_lock = asyncio.Lock()
        return self._tx_lock

    def _load_service_account(self) -> Dict[str, Any]:
        if self._service_account is not None:
            return self._service_account
        for base in (self.flow_dir, self.repo_root):
            key_path = os.path.join(base, 'mainnet-agfarms.pkey')
            if os.path.exists(key_path):
                break
        else:
            raise RuntimeError(f'Service account private key not found. Tried: {os.path.join(self.flow_dir, "mainnet-agfarms.pkey")} and {os.path.join(self.repo_root, "mainnet-agfarms.pkey")}')
        key = open(key_path, 'r').read().strip()
        address = None
        key_id = 0
        signature_algorithm = 'ECDSA_secp256k1'
        hash_algorithm = 'SHA2_256'
        flow_json_path = os.path.join(self.flow_dir, 'flow.json')
        if os.path.exists(flow_json_path):
            with open(flow_json_path) as f:
                cfg = json.load(f)
            if cfg.get('accounts', {}).get('mainnet-agfarms'):
                acc = cfg['accounts']['mainnet-agfarms']
                address = str(acc.get('address', ''))
                if acc.get('key') and isinstance(acc['key'].get('index'), int):
                    key_id = acc['key']['index']
                if acc.get('key', {}).get('signatureAlgorithm'):
                    signature_algorithm = acc['key']['signatureAlgorithm']
                if acc.get('key', {}).get('hashAlgorithm'):
                    hash_algorithm = acc['key']['hashAlgorithm']
        if not address:
            accounts_path = os.path.join(self.flow_dir, 'accounts', 'flow-production.json')
            if os.path.exists(accounts_path):
                with open(accounts_path) as f:
                    cfg = json.load(f)
                if cfg.get('accounts', {}).get('mainnet-agfarms'):
                    acc = cfg['accounts']['mainnet-agfarms']
                    address = str(acc.get('address', ''))
                    if acc.get('key') and isinstance(acc['key'].get('index'), int):
                        key_id = acc['key']['index']
                    if acc.get('key', {}).get('signatureAlgorithm'):
                        signature_algorithm = acc['key']['signatureAlgorithm']
                    if acc.get('key', {}).get('hashAlgorithm'):
                        hash_algorithm = acc['key']['hashAlgorithm']
        if not address:
            raise RuntimeError('Service account address not found in flow.json or flow-production.json')
        self._service_account = {
            'address': address if address.startswith('0x') else f'0x{address}',
            'key': key,
            'keyId': key_id,
            'signatureAlgorithm': signature_algorithm,
            'hashAlgorithm': hash_algorithm
        }
        return self._service_account

    def _load_account_by_name(self, account_name: str) -> Dict[str, Any]:
        if account_name == 'mainnet-agfarms':
            return self._load_service_account()
        key_path = os.path.join(self.flow_dir, 'accounts', 'pkeys', f'{account_name}.pkey')
        if not os.path.exists(key_path):
            raise RuntimeError(f'Private key file not found for account {account_name}: {key_path}')
        key = open(key_path, 'r').read().strip()
        address = None
        key_id = 0
        signature_algorithm = 'ECDSA_P256'
        hash_algorithm = 'SHA3_256'
        flow_json_path = os.path.join(self.flow_dir, 'flow.json')
        if os.path.exists(flow_json_path):
            with open(flow_json_path) as f:
                cfg = json.load(f)
            if cfg.get('accounts', {}).get(account_name):
                acc = cfg['accounts'][account_name]
                address = str(acc.get('address', ''))
                if acc.get('key') and isinstance(acc['key'].get('index'), int):
                    key_id = acc['key']['index']
                if acc.get('key', {}).get('signatureAlgorithm'):
                    signature_algorithm = acc['key']['signatureAlgorithm']
                if acc.get('key', {}).get('hashAlgorithm'):
                    hash_algorithm = acc['key']['hashAlgorithm']
        if not address:
            accounts_path = os.path.join(self.flow_dir, 'accounts', 'flow-production.json')
            if os.path.exists(accounts_path):
                with open(accounts_path) as f:
                    cfg = json.load(f)
                if cfg.get('accounts', {}).get(account_name):
                    acc = cfg['accounts'][account_name]
                    address = str(acc.get('address', ''))
                    if acc.get('key') and isinstance(acc['key'].get('index'), int):
                        key_id = acc['key']['index']
                    if acc.get('key', {}).get('signatureAlgorithm'):
                        signature_algorithm = acc['key']['signatureAlgorithm']
                    if acc.get('key', {}).get('hashAlgorithm'):
                        hash_algorithm = acc['key']['hashAlgorithm']
        if not address:
            raise RuntimeError(f'Account {account_name} not found in flow.json or flow-production.json')
        return {
            'address': address if address.startswith('0x') else f'0x{address}',
            'key': key,
            'keyId': key_id,
            'signatureAlgorithm': signature_algorithm,
            'hashAlgorithm': hash_algorithm
        }

    def _create_signer(self, private_key_hex: str, signature_algo: str, hash_algo: str) -> InMemorySigner:
        hash_map = {'SHA2_256': HashAlgo.SHA2_256, 'SHA3_256': HashAlgo.SHA3_256}
        sign_map = {'ECDSA_P256': SignAlgo.ECDSA_P256, 'ECDSA_secp256k1': SignAlgo.ECDSA_secp256k1}
        return InMemorySigner(
            hash_algo=hash_map.get(hash_algo, HashAlgo.SHA2_256),
            sign_algo=sign_map.get(signature_algo, SignAlgo.ECDSA_secp256k1),
            private_key_hex=private_key_hex
        )

    def _read_cadence(self, path: str) -> str:
        full = path if os.path.isabs(path) else os.path.join(self.flow_dir, path)
        with open(full, 'r') as f:
            return f.read()

    def _build_args(self, args: Optional[List[Any]]) -> List[Value]:
        return [_to_cadence_arg(a) for a in (args or [])]

    def execute_script(self, script_path: str, args: Optional[List[Any]] = None, network: str = 'mainnet') -> Dict[str, Any]:
        return asyncio.run(self._execute_script_async(script_path, args or [], network))

    async def _execute_script_async(self, script_path: str, args: List[Any], network: str) -> Dict[str, Any]:
        started = time.time()
        host, port = _get_access_node(network)
        code = self._read_cadence(script_path)
        cadence_args = self._build_args(args)
        script = Script(code=code, arguments=cadence_args)
        try:
            async with flow_client(host=host, port=port) as client:
                result = await client.execute_script(script=script)
            elapsed = time.time() - started
            data = result
            if hasattr(result, '__class__') and result.__class__.__name__ == 'UFix64':
                data = result.value / UFIX64_FACTOR
            elif hasattr(result, 'value'):
                data = result.value / UFIX64_FACTOR if result.__class__.__name__ == 'UFix64' else result.value
            elif hasattr(result, 'fields') and result.fields:
                f0 = result.fields[0]
                data = f0.value / UFIX64_FACTOR if f0.__class__.__name__ == 'UFix64' else (f0.value if hasattr(f0, 'value') else str(f0))
            return {
                'success': True,
                'stdout': '',
                'stderr': '',
                'returncode': 0,
                'data': data,
                'transaction_id': None,
                'execution_time': elapsed,
                'command': f'flow_py execute_script {script_path}'
            }
        except Exception as e:
            elapsed = time.time() - started
            return {
                'success': False,
                'stdout': '',
                'stderr': str(e),
                'returncode': 1,
                'data': None,
                'transaction_id': None,
                'error_message': str(e),
                'execution_time': elapsed,
                'command': f'flow_py execute_script {script_path}'
            }

    def send_transaction(self, transaction_path: str, args: Optional[List[Any]] = None, roles: Optional[Dict[str, Any]] = None, network: str = 'mainnet', proposer_wallet_id: Optional[str] = None, payer_wallet_id: Optional[str] = None, authorizer_wallet_ids: Optional[List[str]] = None) -> Dict[str, Any]:
        roles = roles or {}
        if not roles and (proposer_wallet_id or payer_wallet_id or authorizer_wallet_ids):
            roles = {
                'proposer': proposer_wallet_id or payer_wallet_id,
                'payer': payer_wallet_id or proposer_wallet_id,
                'authorizer': authorizer_wallet_ids if authorizer_wallet_ids else (proposer_wallet_id or payer_wallet_id)
            }
        return asyncio.run(self._send_transaction_async(transaction_path, args or [], roles, {}, network, proposer_wallet_id, payer_wallet_id, authorizer_wallet_ids))

    def send_transaction_with_private_key(self, transaction_path: str, args: Optional[List[Any]] = None, roles: Optional[Dict[str, Any]] = None, network: str = 'mainnet', private_keys: Optional[Dict[str, str]] = None, proposer_wallet_id: Optional[str] = None, payer_wallet_id: Optional[str] = None, authorizer_wallet_ids: Optional[List[str]] = None) -> Dict[str, Any]:
        roles = roles or {}
        if not roles and (proposer_wallet_id or payer_wallet_id or authorizer_wallet_ids):
            roles = {
                'proposer': proposer_wallet_id or payer_wallet_id,
                'payer': payer_wallet_id or proposer_wallet_id,
                'authorizer': authorizer_wallet_ids if authorizer_wallet_ids else (proposer_wallet_id or payer_wallet_id)
            }
        return asyncio.run(self._send_transaction_async(transaction_path, args or [], roles, private_keys or {}, network, proposer_wallet_id, payer_wallet_id, authorizer_wallet_ids))

    async def _send_transaction_async(self, transaction_path: str, args: List[Any], roles: Dict[str, Any], private_keys: Dict[str, str], network: str, proposer_wallet_id: Optional[str], payer_wallet_id: Optional[str], authorizer_wallet_ids: Optional[List[str]]) -> Dict[str, Any]:
        async with self._get_tx_lock():
            return await self._execute_transaction(transaction_path, args, roles, private_keys, network)

    async def _execute_transaction(self, transaction_path: str, args: List[Any], roles: Dict[str, Any], private_keys: Dict[str, str], network: str) -> Dict[str, Any]:
        started = time.time()
        host, port = _get_access_node(network)
        svc = self._load_service_account()

        def _get_private_key(addr: str) -> Optional[str]:
            norm = (addr if addr.startswith('0x') else f'0x{addr}').lower()
            for k, v in private_keys.items():
                knorm = (k if k.startswith('0x') else f'0x{k}').lower()
                if knorm == norm:
                    return v
            return None

        def resolve_account(val: Any) -> tuple[Address, int, InMemorySigner]:
            if not val:
                addr = Address.from_hex(svc['address'])
                signer = self._create_signer(svc['key'], svc['signatureAlgorithm'], svc['hashAlgorithm'])
                return (addr, svc['keyId'], signer)
            if isinstance(val, str):
                pk = _get_private_key(val)
                if pk:
                    addr = Address.from_hex(val if val.startswith('0x') else f'0x{val}')
                    signer = self._create_signer(pk, 'ECDSA_P256', 'SHA3_256')
                    return (addr, 0, signer)
                acc = self._load_account_by_name(val)
                addr = Address.from_hex(acc['address'])
                signer = self._create_signer(acc['key'], acc['signatureAlgorithm'], acc['hashAlgorithm'])
                return (addr, acc['keyId'], signer)
            raise ValueError(f'Invalid authorization value: {val}')

        proposer_addr, proposer_key_id, proposer_signer = resolve_account(roles.get('proposer'))
        payer_addr, payer_key_id, payer_signer = resolve_account(roles.get('payer'))
        auth_list = roles.get('authorizer')
        if isinstance(auth_list, list):
            authorizers = [resolve_account(a) for a in auth_list]
        elif auth_list:
            authorizers = [resolve_account(auth_list)]
        else:
            authorizers = [(proposer_addr, proposer_key_id, proposer_signer)]

        code = self._read_cadence(transaction_path)
        cadence_args = self._build_args(args)

        try:
            async with flow_client(host=host, port=port) as client:
                block = await client.get_latest_block(is_sealed=True)
                proposer_account = await client.get_account_at_latest_block(address=proposer_addr.bytes)
                seq_num = proposer_account.keys[proposer_key_id].sequence_number if proposer_key_id < len(proposer_account.keys) else proposer_account.keys[0].sequence_number

                tx = Tx(
                    code=code,
                    reference_block_id=block.id,
                    payer=payer_addr,
                    proposal_key=ProposalKey(
                        key_address=proposer_addr,
                        key_id=proposer_key_id,
                        key_sequence_number=seq_num
                    )
                ).with_gas_limit(9999).add_arguments(*cadence_args)

                for auth_addr, auth_key_id, auth_signer in authorizers:
                    tx = tx.add_authorizers(auth_addr)

                seen = set()
                for auth_addr, auth_key_id, auth_signer in authorizers:
                    key = (auth_addr.hex(), auth_key_id)
                    if key not in seen and (auth_addr != payer_addr or auth_key_id != payer_key_id):
                        seen.add(key)
                        tx = tx.with_envelope_signature(auth_addr, auth_key_id, auth_signer)
                payer_key = (payer_addr.hex(), payer_key_id)
                if payer_key not in seen:
                    tx = tx.with_envelope_signature(payer_addr, payer_key_id, payer_signer)

                response = await client.send_transaction(transaction=tx.to_signed_grpc())
                tx_id = response.id.hex()

                result = await client.get_transaction_result(id=response.id)
                wait_start = time.time()
                while result.status != 4 and (time.time() - wait_start) < 120:
                    await asyncio.sleep(1)
                    result = await client.get_transaction_result(id=response.id)
                elapsed = time.time() - started
                if result.status == 4:
                    return {
                        'success': True,
                        'stdout': '',
                        'stderr': '',
                        'returncode': 0,
                        'data': {'id': tx_id, 'status': result.status},
                        'transaction_id': tx_id,
                        'execution_time': elapsed,
                        'command': f'flow_py send_transaction {transaction_path}'
                    }
                return {
                    'success': False,
                    'error_message': f'Transaction status: {result.status}',
                    'transaction_id': tx_id,
                    'execution_time': elapsed,
                    'stderr': f'Transaction status: {result.status}'
                }
        except Exception as e:
            elapsed = time.time() - started
            return {
                'success': False,
                'stdout': '',
                'stderr': str(e),
                'returncode': 1,
                'error_message': str(e),
                'transaction_id': None,
                'execution_time': elapsed,
                'command': f'flow_py send_transaction {transaction_path}'
            }

    def get_transaction(self, transaction_id: str, network: str = 'mainnet') -> Dict[str, Any]:
        return asyncio.run(self._get_transaction_async(transaction_id, network))

    async def _get_transaction_async(self, transaction_id: str, network: str) -> Dict[str, Any]:
        started = time.time()
        host, port = _get_access_node(network)
        tx_id_bytes = bytes.fromhex(transaction_id.replace('0x', ''))
        try:
            async with flow_client(host=host, port=port) as client:
                result = await client.get_transaction_result(id=tx_id_bytes)
                elapsed = time.time() - started
                return {
                    'success': result.status == 4,
                    'data': {'status': result.status},
                    'transaction_id': transaction_id,
                    'execution_time': elapsed
                }
        except Exception as e:
            elapsed = time.time() - started
            return {
                'success': False,
                'error_message': str(e),
                'transaction_id': transaction_id,
                'execution_time': elapsed
            }

    def get_account(self, address: str, network: str = 'mainnet') -> Dict[str, Any]:
        return asyncio.run(self._get_account_async(address, network))

    async def _get_account_async(self, address: str, network: str) -> Dict[str, Any]:
        started = time.time()
        host, port = _get_access_node(network)
        addr = address if address.startswith('0x') else f'0x{address}'
        try:
            async with flow_client(host=host, port=port) as client:
                account = await client.get_account_at_latest_block(address=Address.from_hex(addr).bytes)
                elapsed = time.time() - started
                return {
                    'success': True,
                    'data': {
                        'address': account.address.hex(),
                        'balance': account.balance,
                        'keys': [{'index': k.id, 'sequence_number': k.sequence_number} for k in account.keys],
                        'contracts': dict(account.contracts)
                    },
                    'execution_time': elapsed
                }
        except Exception as e:
            elapsed = time.time() - started
            return {
                'success': False,
                'error_message': str(e),
                'execution_time': elapsed
            }

    def create_account(self, auth_id: str, network: str = 'mainnet') -> Dict[str, Any]:
        return asyncio.run(self._create_account_async(auth_id, network))

    async def _create_account_async(self, auth_id: str, network: str) -> Dict[str, Any]:
        started = time.time()
        host, port = _get_access_node(network)
        svc = self._load_service_account()
        import secrets
        seed = secrets.token_hex(32)
        ak, signer = AccountKey.from_seed(sign_algo=SignAlgo.ECDSA_P256, hash_algo=HashAlgo.SHA3_256, seed=seed)
        public_key_bytes = ak.public_key
        private_key_hex = signer.key.to_string().hex()
        public_key_hex = public_key_bytes.hex()
        try:
            async with self._get_tx_lock():
                async with flow_client(host=host, port=port) as client:
                    block = await client.get_latest_block(is_sealed=True)
                    payer_addr = Address.from_hex(svc['address'])
                    payer_signer = self._create_signer(svc['key'], svc['signatureAlgorithm'], svc['hashAlgorithm'])
                    proposer_account = await client.get_account_at_latest_block(address=payer_addr.bytes)
                    key_id = svc.get('keyId', 0)
                    seq_num = proposer_account.keys[key_id].sequence_number if key_id < len(proposer_account.keys) else proposer_account.keys[0].sequence_number
                    code = self._read_cadence('cadence/transactions/createAccount.cdc')
                    cadence_args = [Array([UInt8(b) for b in public_key_bytes])]
                    tx = Tx(
                        code=code,
                        reference_block_id=block.id,
                        payer=payer_addr,
                        proposal_key=ProposalKey(key_address=payer_addr, key_id=key_id, key_sequence_number=seq_num)
                    ).with_gas_limit(9999).add_arguments(*cadence_args).add_authorizers(payer_addr).with_envelope_signature(payer_addr, key_id, payer_signer)
                    response = await client.send_transaction(transaction=tx.to_signed_grpc())
                    tx_id = response.id.hex()
                    result = await client.get_transaction_result(id=response.id)
                    wait_start = time.time()
                    while result.status != 4 and (time.time() - wait_start) < 120:
                        await asyncio.sleep(1)
                        result = await client.get_transaction_result(id=response.id)
                    elapsed = time.time() - started
                    if result.status != 4:
                        return {'success': False, 'error_message': f'Transaction status: {result.status}', 'transaction_id': tx_id, 'execution_time': elapsed}
                    new_address = None
                    for ev in getattr(result, 'events', []) or []:
                        if 'AccountCreated' not in str(getattr(ev, 'type', '')):
                            continue
                        try:
                            val = getattr(ev, 'value', None)
                            if val is not None and hasattr(val, 'fields'):
                                addr_val = val.fields.get('address') or (val.field_order and val.fields.get(val.field_order[0]))
                                if addr_val is not None and hasattr(addr_val, 'hex'):
                                    new_address = addr_val.hex()
                                    break
                            payload = getattr(ev, 'payload', b'')
                            if isinstance(payload, bytes):
                                decoded = json.loads(payload.decode('utf-8'))
                                v = decoded.get('value', {})
                                fields = v.get('fields', [])
                                for f in fields:
                                    if f.get('name') == 'address' or not new_address:
                                        fv = f.get('value', {})
                                        addr_str = fv.get('value', fv) if isinstance(fv, dict) else fv
                                        if isinstance(addr_str, str) and addr_str.startswith('0x') and len(addr_str) == 18:
                                            new_address = addr_str
                                            break
                        except Exception:
                            pass
                    if not new_address:
                        return {'success': False, 'error_message': 'Could not parse AccountCreated event', 'transaction_id': tx_id, 'execution_time': elapsed}
                    if new_address and not new_address.startswith('0x'):
                        new_address = '0x' + new_address
                    return {
                        'success': True,
                        'address': new_address,
                        'private_key_hex': private_key_hex,
                        'public_key_hex': public_key_hex,
                        'transaction_id': tx_id,
                        'execution_time': elapsed
                    }
        except Exception as e:
            elapsed = time.time() - started
            return {'success': False, 'error_message': str(e), 'transaction_id': None, 'execution_time': elapsed}
