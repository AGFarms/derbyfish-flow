"""
E2E test: create wallet -> fund -> check balance -> send BAIT.
Prints DB record and file contents without writing. Run with: pytest tests/test_create_wallet_e2e.py -v -s
"""
import os
import json
import sys
import uuid

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src', 'python'))
os.chdir(os.path.join(os.path.dirname(__file__), '..'))

from flow_py_adapter import FlowPyAdapter

AUTH_ID_SENDER = 'b3dab218-29c3-4d03-9b5c-edbac9159f80'
INITIAL_FLOW = 0.002
BAIT_AMOUNT = 0.1


def test_create_wallet_e2e():
    adapter = FlowPyAdapter()
    auth_id = f'test-{uuid.uuid4().hex[:8]}'

    print('\n' + '='*60)
    print('STEP 1: Create wallet (on-chain)')
    print('='*60)
    result = adapter.create_account(auth_id, network='mainnet')
    assert result.get('success'), f'create_account failed: {result.get("error_message")}'
    address = result['address']
    private_key_hex = result['private_key_hex']
    public_key_hex = result['public_key_hex']
    tx_id = result.get('transaction_id', '')
    print(f'Created account: {address}')
    print(f'Transaction: {tx_id}')

    print('\n' + '-'*60)
    print('DB RECORD (would INSERT/UPDATE - copy to apply):')
    print('-'*60)
    db_record = {
        'auth_id': auth_id,
        'flow_address': address.replace('0x', '') if address.startswith('0x') else address,
        'flow_private_key': private_key_hex,
        'flow_public_key': public_key_hex
    }
    print(json.dumps(db_record, indent=2))

    print('\n' + '-'*60)
    print('PKEY FILE (would write - copy to apply):')
    print('-'*60)
    pkey_path = f'flow/accounts/pkeys/{auth_id}.pkey'
    print(f'Path: {pkey_path}')
    print(f'Content:\n{private_key_hex}')

    print('\n' + '-'*60)
    print('flow-production.json ENTRY (would add - copy to apply):')
    print('-'*60)
    flow_prod_entry = {
        auth_id: {
            'address': address.replace('0x', '') if address.startswith('0x') else address,
            'key': {
                'type': 'file',
                'location': f'accounts/pkeys/{auth_id}.pkey',
                'signatureAlgorithm': 'ECDSA_P256',
                'hashAlgorithm': 'SHA3_256'
            }
        }
    }
    print(json.dumps(flow_prod_entry, indent=2))

    print('\n' + '='*60)
    print('STEP 2: Fund wallet with initial FLOW from admin')
    print('='*60)
    fund_result = adapter.send_transaction(
        'cadence/transactions/fundWallet.cdc',
        args=[address, INITIAL_FLOW],
        roles={'proposer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms'},
        network='mainnet'
    )
    assert fund_result.get('success'), f'fund failed: {fund_result.get("stderr") or fund_result.get("error_message")}'
    print(f'Funded {INITIAL_FLOW} FLOW. Tx: {fund_result.get("transaction_id")}')

    print('\n' + '='*60)
    print('STEP 3: Check balance')
    print('='*60)
    bal_result = adapter.execute_script('cadence/scripts/checkFlowBalance.cdc', args=[address], network='mainnet')
    assert bal_result.get('success'), f'balance check failed: {bal_result.get("stderr")}'
    flow_bal = bal_result.get('data')
    print(f'FLOW balance: {flow_bal}')

    print('\n' + '='*60)
    print('STEP 4: Send BAIT from auth_id to new wallet')
    print('='*60)
    pkey_path = os.path.join(adapter.flow_dir, 'accounts', 'pkeys', f'{AUTH_ID_SENDER}.pkey')
    if not os.path.exists(pkey_path):
        print(f'SKIP: Sender pkey not found at {pkey_path}')
        print('To run send BAIT step, ensure flow/accounts/pkeys/b3dab218-29c3-4d03-9b5c-edbac9159f80.pkey exists')
    else:
        send_result = adapter.send_transaction(
            'cadence/transactions/sendBait.cdc',
            args=[address, BAIT_AMOUNT],
            roles={'proposer': AUTH_ID_SENDER, 'authorizer': [AUTH_ID_SENDER], 'payer': 'mainnet-agfarms'},
            network='mainnet'
        )
        assert send_result.get('success'), f'send bait failed: {send_result.get("stderr") or send_result.get("error_message")}'
        print(f'Sent {BAIT_AMOUNT} BAIT. Tx: {send_result.get("transaction_id")}')

        bait_result = adapter.execute_script('cadence/scripts/checkBaitBalance.cdc', args=[address], network='mainnet')
        assert bait_result.get('success'), f'bait balance check failed: {bait_result.get("stderr")}'
        bait_bal = bait_result.get('data')
        print(f'BAIT balance: {bait_bal}')

    print('\n' + '='*60)
    print('COPY-PASTE BLOCK (all in one)')
    print('='*60)
    print('''
-- DB (Supabase wallet table):
''' + json.dumps(db_record, indent=2) + '''

-- PKEY file: flow/accounts/pkeys/''' + auth_id + '''.pkey
''' + private_key_hex + '''

-- flow-production.json accounts entry:
''' + json.dumps(flow_prod_entry, indent=2) + '''
''')
    print('='*60)
    print('DONE')
    print('='*60)
