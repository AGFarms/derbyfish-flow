import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import click
from rich.console import Console

from cli.core import resolve_wallet, REPO_ROOT

def _admin_result(r, json_output):
    if json_output:
        import json
        click.echo(json.dumps({
            'success': r.get('success'),
            'transaction_id': r.get('transaction_id'),
            'stderr': r.get('stderr'),
            'error_message': r.get('error_message'),
            'execution_time': r.get('execution_time')
        }, indent=2))
    else:
        if r.get('success'):
            Console().print(f"Success! tx_id: {r.get('transaction_id', 'N/A')}")
        else:
            Console().print(f"Failed: {r.get('stderr') or r.get('error_message', 'Unknown error')}")
            raise SystemExit(1)

@click.group('admin')
def admin_group():
    pass

@admin_group.command('mint-bait')
@click.option('--to', 'to_id', required=True, help='Recipient address or auth_id')
@click.option('--amount', required=True, type=click.FLOAT, help='Amount')
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def mint_bait(ctx, to_id, amount, json_output):
    to_addr, _ = resolve_wallet(to_id, require_private_key=False)
    if not to_addr.startswith('0x'):
        to_addr = f'0x{to_addr}'
    if ctx.obj.get('api_url'):
        import requests
        base = ctx.obj.get('api_url', '').rstrip('/')
        token = ctx.obj.get('admin_secret')
        if not token:
            click.echo('Admin operations require --admin', err=True)
            raise SystemExit(1)
        r = requests.post(f'{base}/transactions/admin-mint-bait', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json={'to_address': to_addr, 'amount': amount}, timeout=30)
        data = r.json() if r.status_code == 200 else {}
        _admin_result(data if isinstance(data, dict) else {'success': r.status_code == 200}, json_output)
        return
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    network = ctx.obj.get('network', 'mainnet')
    r = adapter.send_transaction(
        'cadence/transactions/adminMintBait.cdc', [to_addr, float(amount)],
        roles={'proposer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms'},
        network=network
    )
    _admin_result(r, json_output)

@admin_group.command('burn-bait')
@click.option('--amount', required=True, type=click.FLOAT, help='Amount')
@click.option('--from-wallet', 'from_id', default=None, help='Burn from this wallet (default: admin)')
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def burn_bait(ctx, amount, from_id, json_output):
    if ctx.obj.get('api_url'):
        import requests
        base = ctx.obj.get('api_url', '').rstrip('/')
        token = ctx.obj.get('admin_secret')
        if not token:
            click.echo('Admin operations require --admin', err=True)
            raise SystemExit(1)
        payload = {'amount': amount}
        if from_id:
            from_addr, _ = resolve_wallet(from_id, require_private_key=False)
            if not from_addr.startswith('0x'):
                from_addr = f'0x{from_addr}'
            payload['from_wallet'] = from_addr
        r = requests.post(f'{base}/transactions/admin-burn-bait', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json=payload, timeout=30)
        data = r.json() if r.status_code == 200 else {}
        _admin_result(data if isinstance(data, dict) else {'success': r.status_code == 200}, json_output)
        return
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    network = ctx.obj.get('network', 'mainnet')
    if from_id:
        from_addr, from_pk = resolve_wallet(from_id, require_private_key=True)
        if not from_addr.startswith('0x'):
            from_addr = f'0x{from_addr}'
        admin_addr = '0xed2202de80195438'
        r = adapter.send_transaction_with_private_key(
            'cadence/transactions/sendBait.cdc', [admin_addr, float(amount)],
            roles={'proposer': from_addr, 'authorizer': [from_addr], 'payer': 'mainnet-agfarms'},
            private_keys={from_addr: from_pk}, network=network
        )
        if not r.get('success'):
            _admin_result(r, json_output)
            return
        r = adapter.send_transaction(
            'cadence/transactions/adminBurnBait.cdc', [float(amount)],
            roles={'proposer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms'},
            network=network
        )
    else:
        r = adapter.send_transaction(
            'cadence/transactions/adminBurnBait.cdc', [float(amount)],
            roles={'proposer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms'},
            network=network
        )
    _admin_result(r, json_output)

@admin_group.command('mint-fusd')
@click.option('--to', 'to_id', required=True, help='Recipient address or auth_id')
@click.option('--amount', required=True, type=click.FLOAT, help='Amount')
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def mint_fusd(ctx, to_id, amount, json_output):
    to_addr, _ = resolve_wallet(to_id, require_private_key=False)
    if not to_addr.startswith('0x'):
        to_addr = f'0x{to_addr}'
    if ctx.obj.get('api_url'):
        import requests
        base = ctx.obj.get('api_url', '').rstrip('/')
        token = ctx.obj.get('admin_secret')
        if not token:
            click.echo('Admin operations require --admin', err=True)
            raise SystemExit(1)
        r = requests.post(f'{base}/transactions/admin-mint-fusd', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, json={'to_address': to_addr, 'amount': amount}, timeout=30)
        data = r.json() if r.status_code == 200 else {}
        _admin_result(data if isinstance(data, dict) else {'success': r.status_code == 200}, json_output)
        return
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    network = ctx.obj.get('network', 'mainnet')
    r = adapter.send_transaction(
        'cadence/transactions/adminMintFusd.cdc', [to_addr, float(amount)],
        roles={'proposer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms'},
        network=network
    )
    _admin_result(r, json_output)
