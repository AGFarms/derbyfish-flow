#!/usr/bin/env python3
"""
Re-encrypt wallet.flow_private_key from pkeys using current WALLET_ENCRYPTION_KEY.
Use when WALLET_ENCRYPTION_KEY (or ADMIN_SECRET_KEY if used as encryption key) was rotated;
db encrypted blobs are invalid, but pkeys/ has plaintext keys.

Fetches all wallets from db, reads private key from flow/accounts/pkeys/{auth_id}.pkey,
encrypts with current WALLET_ENCRYPTION_KEY, updates wallet.flow_private_key.
Runs updates in parallel.

Usage:
  cd derbyfish-flow && python scripts/reencrypt_wallets_from_pkeys.py [--pkeys-dir PATH] [--dry-run]
  # If pkeys are at /home/mattricks/pkeys: --pkeys-dir /home/mattricks/pkeys
"""
import argparse
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Optional

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src', 'python'))
os.chdir(os.path.join(os.path.dirname(__file__), '..'))

from dotenv import load_dotenv
load_dotenv()

from wallet_crypto import encrypt_private_key


def process_wallet(wallet: dict, pkeys_dir: str) -> tuple[str, bool, str, Optional[str], Optional[str], Optional[str]]:
    auth_id = wallet.get('auth_id')
    wallet_id = wallet.get('id')
    old_db_key = wallet.get('flow_private_key')
    if not auth_id:
        return (wallet_id or 'unknown', False, 'missing auth_id', None, old_db_key, None)
    pkey_path = os.path.join(pkeys_dir, f'{auth_id}.pkey')
    if not os.path.isfile(pkey_path):
        return (auth_id, False, f'pkey not found: {pkey_path}', None, old_db_key, None)
    try:
        with open(pkey_path) as f:
            plaintext_hex = f.read().strip()
    except Exception as e:
        return (auth_id, False, str(e), None, old_db_key, None)
    if len(plaintext_hex) != 64 or not all(c in '0123456789abcdefABCDEF' for c in plaintext_hex):
        return (auth_id, False, 'invalid pkey format', None, old_db_key, None)
    try:
        encrypted = encrypt_private_key(plaintext_hex)
    except Exception as e:
        return (auth_id, False, f'encrypt: {e}', None, old_db_key, None)
    return (auth_id, True, 'encrypted', encrypted, old_db_key, plaintext_hex)


def main():
    parser = argparse.ArgumentParser(description='Re-encrypt wallet keys from pkeys')
    parser.add_argument('--pkeys-dir', default=None, help='Path to pkeys dir (default: flow/accounts/pkeys)')
    parser.add_argument('--dry-run', action='store_true', help='Do not update db')
    parser.add_argument('--workers', type=int, default=8, help='Parallel workers (default: 8)')
    parser.add_argument('--page-size', type=int, default=500, help='Wallets per page when fetching from db (default: 500)')
    parser.add_argument('-v', '--verbose', action='store_true', default=True, help='Print old key -> new key (default: on)')
    parser.add_argument('-q', '--quiet', action='store_true', help='Minimal output')
    args = parser.parse_args()
    verbose = args.verbose and not args.quiet

    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    enc_key = os.getenv('WALLET_ENCRYPTION_KEY')
    print('=== CONFIG ===')
    print(f'SUPABASE_URL: {url or "(not set)"}')
    print(f'SUPABASE_SERVICE_ROLE_KEY: {"*" * 8}... (len={len(key) if key else 0})')
    print(f'WALLET_ENCRYPTION_KEY: {"*" * 8}... (len={len(enc_key) if enc_key else 0})')
    if not url or not key:
        print('ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY required')
        sys.exit(1)
    if not enc_key or len(enc_key) < 32:
        print('ERROR: WALLET_ENCRYPTION_KEY required (32+ char hex or 44+ base64)')
        sys.exit(1)

    pkeys_dir = args.pkeys_dir or os.path.join(os.getcwd(), 'flow', 'accounts', 'pkeys')
    print(f'pkeys_dir: {pkeys_dir}')
    if not os.path.isdir(pkeys_dir):
        print(f'ERROR: pkeys dir not found: {pkeys_dir}')
        sys.exit(1)

    from supabase import create_client
    supabase = create_client(url, key)
    wallets = []
    page_size = args.page_size
    offset = 0
    while True:
        r = supabase.table('wallet').select('id, auth_id, flow_address, flow_private_key').order('id').range(offset, offset + page_size - 1).execute()
        page = r.data or []
        if not page:
            break
        wallets.extend(page)
        offset += page_size
        if len(page) < page_size:
            break
    print(f'\n=== FETCHED {len(wallets)} WALLETS FROM DB (page_size={page_size}) ===')
    if not wallets:
        print('No wallets to process')
        sys.exit(0)

    ok = 0
    fail = 0
    to_update = []
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = {ex.submit(process_wallet, w, pkeys_dir): w for w in wallets}
        for f in as_completed(futures):
            auth_id, success, msg, encrypted, old_db_key, plaintext_hex = f.result()
            if success:
                ok += 1
                if encrypted:
                    to_update.append((auth_id, encrypted))
                if verbose:
                    print(f'\n--- {auth_id} ---')
                    print(f'  old (db flow_private_key): {old_db_key or "(null)"}')
                    print(f'  pkey (plaintext):         {plaintext_hex or "(none)"}')
                    print(f'  new (encrypted):          {encrypted or "(none)"}')
                    print(f'  old key -> new key: OK')
                else:
                    print(f'  {auth_id}: {msg}')
            else:
                fail += 1
                print(f'\n--- {auth_id} FAIL ---')
                print(f'  old (db flow_private_key): {old_db_key or "(null)"}')
                print(f'  error: {msg}')

    if to_update and not args.dry_run:
        print(f'\n=== UPDATING {len(to_update)} WALLETS IN DB ===')
        for auth_id, encrypted in to_update:
            try:
                supabase.table('wallet').update({'flow_private_key': encrypted}).eq('auth_id', auth_id).execute()
                if verbose:
                    print(f'  {auth_id}: updated flow_private_key -> {encrypted}')
                else:
                    print(f'  {auth_id}: updated')
            except Exception as e:
                print(f'  {auth_id}: update FAIL {e}')
                fail += 1
    elif to_update and args.dry_run:
        print(f'\n=== DRY-RUN: would update {len(to_update)} wallets ===')
        if verbose:
            for auth_id, encrypted in to_update:
                w = next((x for x in wallets if x.get('auth_id') == auth_id), {})
                old_db_key = w.get('flow_private_key')
                print(f'\n  {auth_id}:')
                print(f'    old (db flow_private_key): {old_db_key or "(null)"}')
                print(f'    new (encrypted):          {encrypted}')

    print(f'\n=== DONE: {ok} ok, {fail} failed ===')
    sys.exit(1 if fail else 0)


if __name__ == '__main__':
    main()
