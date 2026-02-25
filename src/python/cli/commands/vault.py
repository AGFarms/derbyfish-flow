import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import click
from rich.console import Console

from cli.core import resolve_wallet, REPO_ROOT

def _vault_result(r, json_output):
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

@click.group('vault')
def vault_group():
    pass

def _run_vault_tx(ctx, target_id, tx_path, args, json_output):
    addr, pk = resolve_wallet(target_id, require_private_key=True)
    if not addr.startswith('0x'):
        addr = f'0x{addr}'
    from flow_py_adapter import FlowPyAdapter
    adapter = FlowPyAdapter(repo_root=REPO_ROOT)
    network = ctx.obj.get('network', 'mainnet')
    if pk:
        r = adapter.send_transaction_with_private_key(
            tx_path, args,
            roles={'proposer': addr, 'authorizer': [addr], 'payer': 'mainnet-agfarms'},
            private_keys={addr: pk}, network=network
        )
    else:
        r = adapter.send_transaction(
            tx_path, args,
            roles={'proposer': target_id, 'authorizer': [target_id], 'payer': 'mainnet-agfarms'},
            network=network
        )
    _vault_result(r, json_output)

@vault_group.command('create-all')
@click.argument('target', required=True)
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def create_all(ctx, target, json_output):
    if ctx.obj.get('api_url'):
        click.echo('vault create-all via API not implemented, use standalone mode', err=True)
        raise SystemExit(1)
    addr, _ = resolve_wallet(target, require_private_key=False)
    if not addr.startswith('0x'):
        addr = f'0x{addr}'
    _run_vault_tx(ctx, target, 'cadence/transactions/createAllVault.cdc', [addr], json_output)

@vault_group.command('create-usdf')
@click.argument('target', required=True)
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def create_usdf(ctx, target, json_output):
    if ctx.obj.get('api_url'):
        click.echo('vault create-usdf via API not implemented, use standalone mode', err=True)
        raise SystemExit(1)
    addr, _ = resolve_wallet(target, require_private_key=False)
    if not addr.startswith('0x'):
        addr = f'0x{addr}'
    _run_vault_tx(ctx, target, 'cadence/transactions/createUsdfVault.cdc', [addr], json_output)

@vault_group.command('reset-all')
@click.argument('target', required=True)
@click.option('--json', 'json_output', is_flag=True)
@click.pass_context
def reset_all(ctx, target, json_output):
    if ctx.obj.get('api_url'):
        click.echo('vault reset-all via API not implemented, use standalone mode', err=True)
        raise SystemExit(1)
    _run_vault_tx(ctx, target, 'cadence/transactions/resetAllVaults.cdc', [], json_output)
