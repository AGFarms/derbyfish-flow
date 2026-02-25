#!/usr/bin/env python3
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src', 'python'))
from flow_py_adapter import FlowPyAdapter

def main():
    flow_dir = os.path.join(os.path.dirname(__file__), '..', 'flow')
    production_path = os.path.join(flow_dir, 'accounts', 'flow-production.json')
    with open(production_path) as f:
        config = json.load(f)
    accounts = list(config.get('accounts', {}).items())[:10]
    adapter = FlowPyAdapter(repo_root=os.path.join(os.path.dirname(__file__), '..'))
    print(f"{'auth_id':<40} {'address':<20} {'BAIT balance':<15} {'status'}")
    print("-" * 90)
    for auth_id, acc in accounts:
        addr = acc.get('address', '')
        if not addr:
            print(f"{auth_id:<40} {'N/A':<20} {'N/A':<15} no address")
            continue
        address = addr if addr.startswith('0x') else f'0x{addr}'
        result = adapter.execute_script(
            script_path='cadence/scripts/checkBaitBalance.cdc',
            args=[address],
            network='mainnet'
        )
        if result.get('success'):
            balance = result.get('data', 'N/A')
            print(f"{auth_id:<40} {address:<20} {balance!s:<15} ok")
        else:
            err = result.get('error_message', result.get('stderr', 'unknown'))
            print(f"{auth_id:<40} {address:<20} {'N/A':<15} FAIL: {err[:50]}")

if __name__ == '__main__':
    main()
