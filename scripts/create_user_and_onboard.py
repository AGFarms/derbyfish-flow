#!/usr/bin/env python3
"""
Create a Supabase user and onboard via the same pipeline as derbyfish-native OnboardWizard.
Triggers: handle_new_user -> wallet INSERT -> webhook -> flow.derby.fish/internal/create-wallet
Then fetches and prints wallet keys.

Usage:
  python scripts/create_user_and_onboard.py [--webhook-secret SECRET]
  WEBHOOK_SECRET or ADMIN_SECRET_KEY env used for manual create-wallet if webhook does not fire.
"""
import argparse
import json
import os
import sys
import time
import secrets
import string

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src', 'python'))
os.chdir(os.path.join(os.path.dirname(__file__), '..'))

from dotenv import load_dotenv
load_dotenv()

EMAIL = 'ranker1@agfarms.dev'
USERNAME = 'ranker1'


def gen_password(length=24):
    alphabet = string.ascii_letters + string.digits + '!@#$%^&*'
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def main():
    parser = argparse.ArgumentParser(description='Create user and onboard via flow.derby.fish')
    parser.add_argument('--webhook-secret', help='WEBHOOK_SECRET/ADMIN_SECRET_KEY for manual create-wallet')
    args = parser.parse_args()
    if args.webhook_secret:
        os.environ['WEBHOOK_SECRET'] = args.webhook_secret

    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    if not url or not key:
        print('ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY required')
        sys.exit(1)

    from supabase import create_client
    supabase = create_client(url, key)

    password = gen_password()
    print(f'Creating user: {EMAIL}')
    print(f'Password: {password}')
    print()

    auth_id = None
    try:
        r = supabase.auth.admin.create_user({
            'email': EMAIL,
            'password': password,
            'email_confirm': True,
        })
        if hasattr(r, 'user') and r.user:
            auth_id = r.user.id
        elif isinstance(r, dict):
            auth_id = r.get('user', {}).get('id') or r.get('id')
    except Exception as e:
        err = str(e).lower()
        if 'already' in err or 'exists' in err or 'registered' in err or 'duplicate' in err:
            print(f'User {EMAIL} already exists. Fetching auth_id...')
            page = 1
            while True:
                resp = supabase.auth.admin.list_users(page=page, per_page=100)
                users_data = resp if isinstance(resp, list) else (getattr(resp, 'data', None) or resp.get('users', []) if isinstance(resp, dict) else [])
                if not users_data:
                    break
                for u in users_data:
                    if isinstance(u, dict):
                        if u.get('email') == EMAIL:
                            auth_id = u.get('id')
                            break
                    elif getattr(u, 'email', None) == EMAIL:
                        auth_id = getattr(u, 'id', None)
                        break
                if auth_id or len(users_data) < 100:
                    break
                page += 1
            if not auth_id:
                print('Could not resolve auth_id for existing user.')
                sys.exit(1)
        else:
            raise

    if not auth_id:
        print('ERROR: Could not get auth_id')
        sys.exit(1)

    print(f'auth_id: {auth_id}')
    print()

    print('Upserting profile (onboard step)...')
    supabase.table('profile').upsert({
        'auth_id': auth_id,
        'username': USERNAME,
        'is_youth': False,
        'parent_profile_id': None,
    }, on_conflict='auth_id').execute()
    pr = supabase.table('profile').select('id').eq('auth_id', auth_id).execute()
    profile_id = pr.data[0]['id'] if pr.data else None
    if profile_id:
        print('Creating identification (onboard step)...')
        supabase.table('identification').upsert({
            'profile_id': profile_id,
            'first_name': 'Ranker',
            'last_name': 'One',
            'sex': 'M',
            'dob': '1990-01-01',
            'address': '123 Test St',
            'verified': False,
        }, on_conflict='profile_id').execute()

    print('Waiting for wallet creation (webhook -> flow.derby.fish)...')
    max_wait = 45
    interval = 2
    elapsed = 0
    wallet_row = None
    while elapsed < max_wait:
        r = supabase.table('wallet').select('*').eq('auth_id', auth_id).execute()
        if r.data and r.data[0].get('flow_address'):
            wallet_row = r.data[0]
            break
        time.sleep(interval)
        elapsed += interval
        print(f'  ... {elapsed}s')

    if not wallet_row or not wallet_row.get('flow_address'):
        webhook_secret = os.getenv('WEBHOOK_SECRET') or os.getenv('ADMIN_SECRET_KEY')
        if webhook_secret:
            print('Webhook may not have fired. Manually invoking flow.derby.fish/internal/create-wallet...')
            import urllib.request
            req = urllib.request.Request(
                'https://flow.derby.fish/internal/create-wallet',
                data=bytes(json.dumps({'record': {'auth_id': auth_id}}), 'utf-8'),
                headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {webhook_secret}'},
                method='POST'
            )
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    result = json.loads(resp.read().decode())
                    if result.get('created') or result.get('address'):
                        print('Wallet created successfully.')
                        time.sleep(2)
                        r = supabase.table('wallet').select('*').eq('auth_id', auth_id).execute()
                        if r.data and r.data[0].get('flow_address'):
                            wallet_row = r.data[0]
            except Exception as e:
                print(f'Manual create-wallet failed: {e}')
        if not wallet_row or not wallet_row.get('flow_address'):
            print('ERROR: Wallet not populated. Set WEBHOOK_SECRET or ADMIN_SECRET_KEY to manually invoke create-wallet.')
            sys.exit(1)

    addr = wallet_row.get('flow_address', '')
    if not addr.startswith('0x'):
        addr = '0x' + addr
    pk_enc = wallet_row.get('flow_private_key')
    pk_plain = None
    if pk_enc:
        try:
            from wallet_crypto import get_plain_private_key
            pk_plain = get_plain_private_key(wallet_row)
        except Exception:
            pk_plain = pk_enc if (pk_enc and len(pk_enc) == 64 and all(c in '0123456789abcdef' for c in pk_enc.lower())) else '[encrypted]'

    print()
    print('='*60)
    print('WALLET KEYS')
    print('='*60)
    print(f'flow_address:    {addr}')
    print(f'flow_private_key: {pk_plain or "[encrypted - need WALLET_ENCRYPTION_KEY]"}')
    print(f'flow_public_key:  {wallet_row.get("flow_public_key", "")}')
    print('='*60)
    print()
    print(f'Login: {EMAIL}')
    print(f'Password: {password}')
    print()


if __name__ == '__main__':
    main()
