#!/usr/bin/env python3
import argparse
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src', 'python'))
os.chdir(os.path.join(os.path.dirname(__file__), '..'))

from dotenv import load_dotenv
load_dotenv()

from supabase import create_client
from transaction_logger import TransactionLogger
from transaction_tracker import run_tracker_cycle


def main():
    parser = argparse.ArgumentParser(description='Update transaction status from Flow REST API')
    parser.add_argument('--cycles', type=int, default=1, help='Number of tracker cycles to run')
    parser.add_argument('--network', default='mainnet', help='Flow network (mainnet or testnet)')
    args = parser.parse_args()

    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    if not url or not key:
        print('ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY required')
        sys.exit(1)

    supabase = create_client(url, key)
    transaction_logger = TransactionLogger(supabase)

    total = 0
    for i in range(args.cycles):
        updated = run_tracker_cycle(supabase, transaction_logger, network=args.network)
        total += updated
        if args.cycles > 1:
            print(f'Cycle {i + 1}: updated {updated} transaction(s)')

    print(f'Total updated: {total} transaction(s)')


if __name__ == '__main__':
    main()
