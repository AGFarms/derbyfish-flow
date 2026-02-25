import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import click
from rich.console import Console
from rich.table import Table

from cli.core import get_all_wallets_from_supabase, get_recent_transactions, REPO_ROOT

def run_mission_standalone(ctx, json_output):
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    wallets = get_all_wallets_from_supabase()
    wallet_count = len(wallets)
    total_bait = 0.0
    total_flow = 0.0
    errors = []
    for w in wallets[:50]:
        addr = w.get('flow_address', '')
        if not addr:
            continue
        if not addr.startswith('0x'):
            addr = f'0x{addr}'
        try:
            r = adapter.execute_script('cadence/scripts/checkBaitBalance.cdc', [addr], ctx.obj.get('network', 'mainnet'))
            if r.get('success') and r.get('data') is not None:
                total_bait += float(r['data'])
        except Exception as e:
            errors.append(str(e))
        try:
            r = adapter.execute_script('cadence/scripts/checkFlowBalance.cdc', [addr], ctx.obj.get('network', 'mainnet'))
            if r.get('success') and r.get('data') is not None:
                total_flow += float(r['data'])
        except Exception as e:
            errors.append(str(e))
    health = 'ok'
    try:
        r = adapter.execute_script('cadence/scripts/checkBaitBalance.cdc', ['0xed2202de80195438'], ctx.obj.get('network', 'mainnet'))
        if not r.get('success'):
            health = 'degraded'
    except Exception:
        health = 'error'
    recent = get_recent_transactions(5)
    if json_output:
        import json
        click.echo(json.dumps({
            'wallet_count': wallet_count,
            'total_bait': total_bait,
            'total_flow': total_flow,
            'health': health,
            'recent_transactions': recent,
            'errors': errors[:5]
        }, indent=2))
        return
    console = Console()
    table = Table(title='Mission Control')
    table.add_column('Metric', style='cyan')
    table.add_column('Value', style='green')
    table.add_row('Wallets', str(wallet_count))
    table.add_row('Total BAIT', f'{total_bait:.2f}')
    table.add_row('Total FLOW', f'{total_flow:.2f}')
    table.add_row('Health', health)
    console.print(table)
    if recent:
        tx_table = Table(title='Recent Transactions')
        tx_table.add_column('ID', style='dim')
        tx_table.add_column('Status')
        tx_table.add_column('Created')
        for t in recent:
            tx_table.add_row(
                str(t.get('id', ''))[:8] + '...',
                t.get('status', 'unknown'),
                str(t.get('created_at', ''))[:19]
            )
        console.print(tx_table)

def run_mission_api(ctx, json_output):
    import requests
    base = ctx.obj.get('api_url', '').rstrip('/')
    token = ctx.obj.get('admin_secret') or ctx.obj.get('jwt_token')
    headers = {'Authorization': f'Bearer {token}'} if token else {}
    try:
        r = requests.get(f'{base}/health', headers=headers, timeout=5)
        health = 'ok' if r.status_code == 200 else 'degraded'
    except Exception:
        health = 'error'
    try:
        r = requests.get(f'{base}/background/tasks', headers=headers, timeout=5)
        tasks = r.json().get('tasks', {}) if r.status_code == 200 else {}
    except Exception:
        tasks = {}
    if json_output:
        import json
        click.echo(json.dumps({
            'health': health,
            'background_tasks': len(tasks),
            'api_url': base
        }, indent=2))
        return
    console = Console()
    table = Table(title='Mission Control (API)')
    table.add_column('Metric', style='cyan')
    table.add_column('Value', style='green')
    table.add_row('Health', health)
    table.add_row('Background Tasks', str(len(tasks)))
    table.add_row('API URL', base)
    console.print(table)

@click.command('mission')
@click.pass_context
@click.option('--json', 'json_output', is_flag=True, help='Output as JSON')
def mission(ctx, json_output):
    if ctx.obj.get('api_url'):
        run_mission_api(ctx, json_output)
    else:
        run_mission_standalone(ctx, json_output)
