import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

import click
from dotenv import load_dotenv

load_dotenv()

from cli.commands.mission import mission
from cli.commands.balance import balance
from cli.commands.tx import tx_group
from cli.commands.admin import admin_group
from cli.commands.vault import vault_group


@click.group()
@click.option('--api', 'api_url', default=None, envvar='DERBYFISH_FLOW_API', help='Use API mode (base URL)')
@click.option('--admin', 'admin_mode', is_flag=True, help='Use admin auth')
@click.option('--admin-secret', 'admin_secret', default=None, envvar='ADMIN_SECRET_KEY', help='Admin secret key')
@click.option('--jwt', 'jwt_token', default=None, envvar='DERBYFISH_JWT', help='JWT token for user auth')
@click.option('--user', 'user_auth_id', default=None, help='User auth_id for context')
@click.option('--network', default='mainnet', type=click.Choice(['mainnet', 'testnet']), help='Flow network')
@click.pass_context
def cli(ctx, api_url, admin_mode, admin_secret, jwt_token, user_auth_id, network):
    ctx.ensure_object(dict)
    ctx.obj['api_url'] = api_url
    ctx.obj['network'] = network
    ctx.obj['user_auth_id'] = user_auth_id
    if admin_mode or admin_secret:
        ctx.obj['admin_secret'] = admin_secret or os.getenv('ADMIN_SECRET_KEY')
    else:
        ctx.obj['admin_secret'] = None
    ctx.obj['jwt_token'] = jwt_token


cli.add_command(mission)
cli.add_command(balance)
cli.add_command(tx_group, name='tx')
cli.add_command(admin_group, name='admin')
cli.add_command(vault_group, name='vault')


def main():
    cli()
