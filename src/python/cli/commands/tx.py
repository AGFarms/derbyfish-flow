import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import click
from rich.console import Console

from cli.core import resolve_wallet, REPO_ROOT

def _do_send_bait(ctx, from_id, to_id, amount):
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    network = ctx.obj.get('network', 'mainnet')
    to_addr, _ = resolve_wallet(to_id, require_private_key=False)
    from_addr, from_pk = resolve_wallet(from_id, require_private_key=True)
    if not to_addr.startswith('0x'):
        to_addr = f'0x{to_addr}'
    if not from_addr.startswith('0x'):
        from_addr = f'0x{from_addr}'
    amount_f = float(amount)
    if from_pk:
        r = adapter.send_transaction_with_private_key(
            'cadence/transactions/sendBait.cdc', [to_addr, amount_f],
            roles={'proposer': from_addr, 'authorizer': [from_addr], 'payer': 'mainnet-agfarms'},
            private_keys={from_addr: from_pk}, network=network
        )
    else:
        r = adapter.send_transaction(
            'cadence/transactions/sendBait.cdc', [to_addr, amount_f],
            roles={'proposer': from_id, 'authorizer': [from_id], 'payer': 'mainnet-agfarms'},
            network=network
        )
    return r

def _do_send_fusd(ctx, from_id, to_id, amount):
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    network = ctx.obj.get('network', 'mainnet')
    to_addr, _ = resolve_wallet(to_id, require_private_key=False)
    from_addr, from_pk = resolve_wallet(from_id, require_private_key=True)
    if not to_addr.startswith('0x'):
        to_addr = f'0x{to_addr}'
    if not from_addr.startswith('0x'):
        from_addr = f'0x{from_addr}'
    amount_f = float(amount)
    if from_pk:
        r = adapter.send_transaction_with_private_key(
            'cadence/transactions/sendFusd.cdc', [to_addr, amount_f],
            roles={'proposer': from_addr, 'authorizer': [from_addr], 'payer': 'mainnet-agfarms'},
            private_keys={from_addr: from_pk}, network=network
        )
    else:
        r = adapter.send_transaction(
            'cadence/transactions/sendFusd.cdc', [to_addr, amount_f],
            roles={'proposer': from_id, 'authorizer': [from_id], 'payer': 'mainnet-agfarms'},
            network=network
        )
    return r

def _do_send_flow(ctx, from_id, to_id, amount):
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    network = ctx.obj.get('network', 'mainnet')
    to_addr, _ = resolve_wallet(to_id, require_private_key=False)
    if not to_addr.startswith('0x'):
        to_addr = f'0x{to_addr}'
    amount_f = float(amount)
    if from_id:
        from_addr, from_pk = resolve_wallet(from_id, require_private_key=True)
        if not from_addr.startswith('0x'):
            from_addr = f'0x{from_addr}'
        if from_pk:
            r = adapter.send_transaction_with_private_key(
                'cadence/transactions/fundWallet.cdc', [to_addr, amount_f],
                roles={'proposer': from_addr, 'authorizer': [from_addr], 'payer': from_addr},
                private_keys={from_addr: from_pk}, network=network
            )
        else:
            r = adapter.send_transaction(
                'cadence/transactions/fundWallet.cdc', [to_addr, amount_f],
                roles={'proposer': from_id, 'authorizer': [from_id], 'payer': from_id},
                network=network
            )
    else:
        r = adapter.send_transaction(
            'cadence/transactions/fundWallet.cdc', [to_addr, amount_f],
            roles={'proposer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms'},
            network=network
        )
    return r

def _do_swap_bait_for_fusd(ctx, from_id, amount):
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    network = ctx.obj.get('network', 'mainnet')
    from_addr, from_pk = resolve_wallet(from_id, require_private_key=True)
    if not from_addr.startswith('0x'):
        from_addr = f'0x{from_addr}'
    amount_f = float(amount)
    if from_pk:
        r = adapter.send_transaction_with_private_key(
            'cadence/transactions/swapBaitForFusd.cdc', [amount_f],
            roles={'proposer': from_addr, 'authorizer': [from_addr], 'payer': 'mainnet-agfarms'},
            private_keys={from_addr: from_pk}, network=network
        )
    else:
        r = adapter.send_transaction(
            'cadence/transactions/swapBaitForFusd.cdc', [amount_f],
            roles={'proposer': from_id, 'authorizer': [from_id], 'payer': 'mainnet-agfarms'},
            network=network
        )
    return r

def _do_swap_fusd_for_bait(ctx, from_id, amount):
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    network = ctx.obj.get('network', 'mainnet')
    from_addr, from_pk = resolve_wallet(from_id, require_private_key=True)
    if not from_addr.startswith('0x'):
        from_addr = f'0x{from_addr}'
    amount_f = float(amount)
    if from_pk:
        r = adapter.send_transaction_with_private_key(
            'cadence/transactions/swapFusdForBait.cdc', [amount_f],
            roles={'proposer': from_addr, 'authorizer': [from_addr], 'payer': 'mainnet-agfarms'},
            private_keys={from_addr: from_pk}, network=network
        )
    else:
        r = adapter.send_transaction(
            'cadence/transactions/swapFusdForBait.cdc', [amount_f],
            roles={'proposer': from_id, 'authorizer': [from_id], 'payer': 'mainnet-agfarms'},
            network=network
        )
    return r

def _tx_result(r, json_output):
    err = r.get('stderr') or r.get('error_message') or r.get('error')
    if json_output:
        import json
        click.echo(json.dumps({
            'success': r.get('success'),
            'transaction_id': r.get('transaction_id'),
            'stderr': r.get('stderr'),
            'error_message': r.get('error_message'),
            'error': r.get('error'),
            'execution_time': r.get('execution_time')
        }, indent=2))
    else:
        if r.get('success'):
            Console().print(f"Success! tx_id: {r.get('transaction_id', 'N/A')}")
        else:
            Console().print(f"Failed: {err or 'Unknown error'}")
            raise SystemExit(1)

@click.group('tx')
def tx_group():
    pass

@tx_group.command('send-bait')
@click.option('--from', 'from_id', required=True, help='Sender address or auth_id')
@click.option('--to', 'to_id', required=True, help='Recipient address or auth_id')
@click.option('--amount', required=True, type=click.FLOAT, help='Amount')
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def send_bait(ctx, from_id, to_id, amount, json_output):
    if ctx.obj.get('api_url'):
        import requests
        base = ctx.obj.get('api_url', '').rstrip('/')
        token = ctx.obj.get('jwt_token') or ctx.obj.get('admin_secret')
        if not token:
            click.echo('API mode requires --jwt for send-bait', err=True)
            raise SystemExit(1)
        to_addr, _ = resolve_wallet(to_id, require_private_key=False)
        if not to_addr.startswith('0x'):
            to_addr = f'0x{to_addr}'
        r = requests.post(f'{base}/transactions/send-bait', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json={'to_address': to_addr, 'amount': amount}, timeout=30)
        data = r.json() if r.status_code == 200 else {}
        if not data.get('success') and r.status_code != 200:
            data = r.json() if r.text else {'error': r.text}
        _tx_result(data if isinstance(data, dict) else {'success': r.status_code == 200, 'transaction_id': data.get('transaction_id')}, json_output)
        return
    r = _do_send_bait(ctx, from_id, to_id, amount)
    _tx_result(r, json_output)

@tx_group.command('send-fusd')
@click.option('--from', 'from_id', required=True, help='Sender address or auth_id')
@click.option('--to', 'to_id', required=True, help='Recipient address or auth_id')
@click.option('--amount', required=True, type=click.FLOAT, help='Amount')
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def send_fusd(ctx, from_id, to_id, amount, json_output):
    if ctx.obj.get('api_url'):
        click.echo('send-fusd via API not implemented, use standalone mode', err=True)
        raise SystemExit(1)
    r = _do_send_fusd(ctx, from_id, to_id, amount)
    _tx_result(r, json_output)

@tx_group.command('send-flow')
@click.option('--from', 'from_id', default=None, help='Payer address or auth_id (default: mainnet-agfarms)')
@click.option('--to', 'to_id', required=True, help='Recipient address or auth_id')
@click.option('--amount', required=True, type=click.FLOAT, help='Amount')
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def send_flow(ctx, from_id, to_id, amount, json_output):
    if ctx.obj.get('api_url'):
        import requests
        base = ctx.obj.get('api_url', '').rstrip('/')
        token = ctx.obj.get('admin_secret') or ctx.obj.get('jwt_token')
        if not token:
            click.echo('API mode requires --admin or --jwt', err=True)
            raise SystemExit(1)
        to_addr, _ = resolve_wallet(to_id, require_private_key=False)
        if not to_addr.startswith('0x'):
            to_addr = f'0x{to_addr}'
        r = requests.post(f'{base}/transactions/deposit-flow', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json={'to_address': to_addr, 'amount': amount}, timeout=30)
        data = r.json() if r.status_code == 200 else {}
        _tx_result(data if isinstance(data, dict) else {'success': r.status_code == 200}, json_output)
        return
    r = _do_send_flow(ctx, from_id, to_id, amount)
    _tx_result(r, json_output)

@tx_group.command('swap-bait-for-fusd')
@click.option('--from', 'from_id', required=True, help='Sender address or auth_id')
@click.option('--amount', required=True, type=click.FLOAT, help='Amount')
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def swap_bait_for_fusd(ctx, from_id, amount, json_output):
    if ctx.obj.get('api_url'):
        import requests
        base = ctx.obj.get('api_url', '').rstrip('/')
        token = ctx.obj.get('jwt_token') or ctx.obj.get('admin_secret')
        if not token:
            click.echo('API mode requires --jwt', err=True)
            raise SystemExit(1)
        r = requests.post(f'{base}/transactions/swap-bait-for-fusd', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json={'amount': amount}, timeout=30)
        data = r.json() if r.status_code == 200 else {}
        _tx_result(data if isinstance(data, dict) else {'success': r.status_code == 200}, json_output)
        return
    r = _do_swap_bait_for_fusd(ctx, from_id, amount)
    _tx_result(r, json_output)

@tx_group.command('swap-fusd-for-bait')
@click.option('--from', 'from_id', required=True, help='Sender address or auth_id')
@click.option('--amount', required=True, type=click.FLOAT, help='Amount')
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def swap_fusd_for_bait(ctx, from_id, amount, json_output):
    if ctx.obj.get('api_url'):
        import requests
        base = ctx.obj.get('api_url', '').rstrip('/')
        token = ctx.obj.get('jwt_token') or ctx.obj.get('admin_secret')
        if not token:
            click.echo('API mode requires --jwt', err=True)
            raise SystemExit(1)
        r = requests.post(f'{base}/transactions/swap-fusd-for-bait', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json={'amount': amount}, timeout=30)
        data = r.json() if r.status_code == 200 else {}
        _tx_result(data if isinstance(data, dict) else {'success': r.status_code == 200}, json_output)
        return
    r = _do_swap_fusd_for_bait(ctx, from_id, amount)
    _tx_result(r, json_output)
