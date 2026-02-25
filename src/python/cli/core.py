import os
import re
import json
from typing import Optional, Tuple
from dotenv import load_dotenv

load_dotenv()

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
FLOW_DIR = os.path.join(REPO_ROOT, 'flow')
PRODUCTION_PATH = os.path.join(FLOW_DIR, 'accounts', 'flow-production.json')
PKEYS_DIR = os.path.join(FLOW_DIR, 'accounts', 'pkeys')

UUID_PATTERN = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', re.I)
HEX_ADDRESS_PATTERN = re.compile(r'^[0-9a-f]{16}$', re.I)

def is_flow_address(identifier: str) -> bool:
    clean = identifier.replace('0x', '') if identifier.startswith('0x') else identifier
    return len(clean) == 16 and HEX_ADDRESS_PATTERN.match(clean) is not None

def is_uuid(identifier: str) -> bool:
    return UUID_PATTERN.match(identifier) is not None

def normalize_address(addr: str) -> str:
    if not addr:
        return ''
    clean = addr.replace('0x', '') if addr.startswith('0x') else addr
    return f'0x{clean}' if len(clean) == 16 else addr

def _load_production_config() -> dict:
    if not os.path.exists(PRODUCTION_PATH):
        return {}
    with open(PRODUCTION_PATH) as f:
        return json.load(f)

def _get_supabase():
    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    if not url or not key:
        return None
    from supabase import create_client
    return create_client(url, key)

def resolve_wallet(identifier: str, require_private_key: bool = False) -> Tuple[str, Optional[str]]:
    if not identifier:
        raise ValueError('Wallet identifier is required')
    identifier = identifier.strip()
    if is_flow_address(identifier):
        addr = normalize_address(identifier)
        if require_private_key:
            prod = _load_production_config()
            for auth_id, acc in prod.get('accounts', {}).items():
                a = acc.get('address', '')
                if a and normalize_address(a) == addr:
                    pkey_path = acc.get('key', {}).get('location') if isinstance(acc.get('key'), dict) else None
                    if pkey_path:
                        full_path = os.path.join(FLOW_DIR, pkey_path) if not os.path.isabs(pkey_path) else pkey_path
                        if os.path.exists(full_path):
                            with open(full_path) as f:
                                return (addr, f.read().strip())
            supabase = _get_supabase()
            if supabase:
                clean = addr.replace('0x', '')
                r = supabase.table('wallet').select('flow_address, flow_private_key').eq('flow_address', clean).execute()
                if r.data and len(r.data) > 0 and r.data[0].get('flow_private_key'):
                    try:
                        from wallet_crypto import get_plain_private_key
                        pk = get_plain_private_key(r.data[0])
                        if pk:
                            return (addr, pk)
                    except Exception:
                        pass
                    return (addr, r.data[0]['flow_private_key'])
        return (addr, None)
    if is_uuid(identifier):
        prod = _load_production_config()
        if identifier in prod.get('accounts', {}):
            acc = prod['accounts'][identifier]
            addr = acc.get('address', '')
            if addr:
                addr = normalize_address(addr)
                pkey_path = acc.get('key', {}).get('location') if isinstance(acc.get('key'), dict) else None
                pk = None
                if pkey_path:
                    full_path = os.path.join(FLOW_DIR, pkey_path) if not os.path.isabs(pkey_path) else pkey_path
                    if os.path.exists(full_path):
                        with open(full_path) as f:
                            pk = f.read().strip()
                if not pk and require_private_key:
                    pkey_file = os.path.join(PKEYS_DIR, f'{identifier}.pkey')
                    if os.path.exists(pkey_file):
                        with open(pkey_file) as f:
                            pk = f.read().strip()
                if not pk and require_private_key:
                    supabase = _get_supabase()
                    if supabase:
                        r = supabase.table('wallet').select('flow_address, flow_private_key').eq('auth_id', identifier).execute()
                        if r.data and len(r.data) > 0:
                            row = r.data[0]
                            addr = normalize_address(row.get('flow_address', addr))
                            try:
                                from wallet_crypto import get_plain_private_key
                                pk = get_plain_private_key(row)
                            except Exception:
                                pk = row.get('flow_private_key')
                return (addr, pk)
        supabase = _get_supabase()
        if supabase:
            r = supabase.table('wallet').select('flow_address, flow_private_key').eq('auth_id', identifier).execute()
            if r.data and len(r.data) > 0:
                row = r.data[0]
                addr = normalize_address(row.get('flow_address', ''))
                pk = None
                if require_private_key and row.get('flow_private_key'):
                    try:
                        from wallet_crypto import get_plain_private_key
                        pk = get_plain_private_key(row)
                    except Exception:
                        pk = row.get('flow_private_key')
                return (addr, pk)
        raise ValueError(f'Wallet not found for auth_id: {identifier}')
    raise ValueError(f'Invalid wallet identifier: {identifier}')

def get_all_wallets_from_supabase() -> list:
    supabase = _get_supabase()
    if not supabase:
        return []
    all_rows = []
    page = 0
    per_page = 1000
    while True:
        r = supabase.table('wallet').select('id, auth_id, flow_address').range(page * per_page, (page + 1) * per_page - 1).execute()
        if not r.data:
            break
        all_rows.extend(r.data)
        if len(r.data) < per_page:
            break
        page += 1
    return all_rows

def get_recent_transactions(limit: int = 10) -> list:
    supabase = _get_supabase()
    if not supabase:
        return []
    r = supabase.table('transactions').select('*').order('created_at', desc=True).limit(limit).execute()
    return r.data or []
