import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import click
from rich.console import Console
from rich.table import Table

from cli.core import resolve_wallet, REPO_ROOT

def run_balance_standalone(ctx, address, flow_only, all_balances, contract_usdf, json_output):
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    network = ctx.obj.get('network', 'mainnet')
    if contract_usdf:
        if not ctx.obj.get('admin_secret'):
            click.echo('--contract-usdf requires admin mode', err=True)
            raise SystemExit(1)
        r = adapter.send_transaction(
            'cadence/transactions/checkContractUsdfBalance.cdc', [],
            roles={'proposer': 'mainnet-agfarms', 'authorizer': 'mainnet-agfarms', 'payer': 'mainnet-agfarms'},
            network=network
        )
        if json_output:
            import json
            click.echo(json.dumps(r, indent=2))
        else:
            Console().print(r.get('stdout', r.get('stderr', str(r))))
        return
    if not address:
        click.echo('Address or auth_id required', err=True)
        raise SystemExit(1)
    addr, _ = resolve_wallet(address, require_private_key=False)
    if not addr.startswith('0x'):
        addr = f'0x{addr}'
    bait = None
    flow = None
    if not flow_only:
        r = adapter.execute_script('cadence/scripts/checkBaitBalance.cdc', [addr], network)
        if r.get('success') and r.get('data') is not None:
            bait = float(r['data'])
    if flow_only or all_balances:
        r = adapter.execute_script('cadence/scripts/checkFlowBalance.cdc', [addr], network)
        if r.get('success') and r.get('data') is not None:
            flow = float(r['data'])
    if json_output:
        import json
        out = {'address': addr}
        if bait is not None:
            out['bait'] = bait
        if flow is not None:
            out['flow'] = flow
        click.echo(json.dumps(out, indent=2))
        return
    console = Console()
    table = Table(title=f'Balance: {addr}')
    table.add_column('Token', style='cyan')
    table.add_column('Balance', style='green')
    if bait is not None:
        table.add_row('BAIT', f'{bait:.4f}')
    if flow is not None:
        table.add_row('FLOW', f'{flow:.4f}')
    if bait is None and flow is None:
        table.add_row('-', 'Unable to fetch')
    console.print(table)

def run_balance_api(ctx, address, flow_only, all_balances, contract_usdf, json_output):
    import requests
    base = ctx.obj.get('api_url', '').rstrip('/')
    token = ctx.obj.get('admin_secret') or ctx.obj.get('jwt_token')
    if not token:
        click.echo('API mode requires --admin or --jwt', err=True)
        raise SystemExit(1)
    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    if contract_usdf:
        r = requests.get(f'{base}/transactions/check-contract-usdf-balance', headers=headers, timeout=30)
        if json_output:
            click.echo(r.text)
        else:
            Console().print(r.json() if r.headers.get('content-type', '').startswith('application/json') else r.text)
        return
    if flow_only or all_balances:
        click.echo('FLOW balance requires standalone mode (no --api)', err=True)
        raise SystemExit(1)
    addr_param = ''
    if address:
        addr, _ = resolve_wallet(address, require_private_key=False)
        addr_param = f'?address={addr}'
    r = requests.get(f'{base}/scripts/check-bait-balance{addr_param}', headers=headers, timeout=10)
    data = r.json() if r.status_code == 200 else {}
    if json_output:
        import json
        click.echo(json.dumps(data, indent=2))
    else:
        if data.get('success') and data.get('data') is not None:
            Console().print(f"BAIT: {data['data']}")
        else:
            Console().print(data.get('error', data.get('stderr', str(data))))

@click.command('balance')
@click.argument('address', required=False)
@click.option('--flow', 'flow_only', is_flag=True, help='Show FLOW balance only')
@click.option('--all', 'all_balances', is_flag=True, help='Show BAIT and FLOW')
@click.option('--contract-usdf', is_flag=True, help='Show contract USDF balance (admin)')
@click.option('--json', 'json_output', is_flag=True, help='Output as JSON')
@click.pass_context
def balance(ctx, address, flow_only, all_balances, contract_usdf, json_output):
    if ctx.obj.get('api_url'):
        run_balance_api(ctx, address, flow_only, all_balances, contract_usdf, json_output)
    else:
        run_balance_standalone(ctx, address, flow_only, all_balances, contract_usdf, json_output)
