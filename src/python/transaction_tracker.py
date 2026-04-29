import json
import os
import sys
import threading
import time
from typing import Any, Dict, List, Optional

import requests

ADMIN_WALLET_ID = '77ef3a77-19e8-49d9-bcc7-f89872378622'


def _is_valid_wallet_id(wallet_id: Optional[str]) -> bool:
    if not wallet_id:
        return False
    import re
    uuid_regex = r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
    return bool(re.match(uuid_regex, str(wallet_id), re.I))


def log_transaction_result(
    result: Dict[str, Any],
    transaction_type: str,
    transaction_path: str,
    args: List[Any],
    supabase,
    transaction_logger,
    proposer_wallet_id: Optional[str] = None,
    payer_wallet_id: Optional[str] = None,
    authorizer_wallet_ids: Optional[List[str]] = None,
    network: str = 'mainnet',
    result_data_extra: Optional[Dict[str, Any]] = None,
) -> None:
    if not result.get('success') or not supabase or not transaction_logger:
        return
    flow_tx_id = result.get('transaction_id')
    if not flow_tx_id:
        return
    if not _is_valid_wallet_id(proposer_wallet_id):
        proposer_wallet_id = ADMIN_WALLET_ID
    if not _is_valid_wallet_id(payer_wallet_id):
        payer_wallet_id = ADMIN_WALLET_ID
    if not authorizer_wallet_ids or not any(_is_valid_wallet_id(w) for w in authorizer_wallet_ids):
        authorizer_wallet_ids = [ADMIN_WALLET_ID]
    exec_time = result.get('execution_time') or 0
    exec_time_ms = int(exec_time * 1000) if isinstance(exec_time, (int, float)) else 0
    try:
        tx_row = transaction_logger.create_transaction(
            transaction_type=transaction_type,
            transaction_path=transaction_path,
            args=args,
            proposer_wallet_id=proposer_wallet_id,
            payer_wallet_id=payer_wallet_id,
            authorizer_wallet_ids=authorizer_wallet_ids,
            network=network,
        )
        if tx_row and tx_row.get('id'):
            rdata = {'flow_transaction_id': flow_tx_id}
            if result_data_extra:
                rdata.update(result_data_extra)
            transaction_logger.update_transaction_sealed(
                tx_row['id'],
                result_data=rdata,
                execution_time_ms=exec_time_ms,
            )
            transaction_logger.update_transaction(tx_row['id'], {'flow_transaction_id': flow_tx_id})
            enrich_row = {
                **tx_row,
                'flow_transaction_id': flow_tx_id,
                'execution_time_ms': exec_time_ms,
                'result_data': rdata,
                'network': network,
            }
            threading.Thread(
                target=update_transaction_with_flow_data,
                args=(enrich_row, supabase, transaction_logger, network),
                daemon=True,
            ).start()
    except Exception as e:
        print(f'[transaction_tracker] log_transaction_result error: {e}', file=sys.stderr)

FLOW_REST_BASE = {
    'mainnet': 'https://rest-mainnet.onflow.org',
    'testnet': 'https://rest-testnet.onflow.org',
}


def fetch_transaction_from_flow(flow_tx_id: str, network: str = 'mainnet') -> Optional[Dict[str, Any]]:
    base = FLOW_REST_BASE.get(network, FLOW_REST_BASE['mainnet'])
    url = f'{base}/v1/transactions/{flow_tx_id}?expand=result'
    try:
        resp = requests.get(url, timeout=15)
        if resp.status_code == 404:
            return None
        resp.raise_for_status()
        data = resp.json()
        result = data.get('result')
        if not result:
            return {'status': 'Unknown', 'block_id': None, 'computation_used': None, 'events': [], 'error_message': ''}
        return {
            'status': result.get('status', ''),
            'block_id': result.get('block_id'),
            'computation_used': result.get('computation_used'),
            'events': result.get('events', []),
            'error_message': result.get('error_message', '') or ''
        }
    except requests.RequestException as e:
        print(f'[transaction_tracker] fetch_transaction_from_flow error: {e}', file=sys.stderr)
        return None
    except (json.JSONDecodeError, KeyError) as e:
        print(f'[transaction_tracker] parse error: {e}', file=sys.stderr)
        return None


def fetch_block_from_flow(block_id: str, network: str = 'mainnet') -> Optional[Dict[str, Any]]:
    if not block_id:
        return None
    base = FLOW_REST_BASE.get(network, FLOW_REST_BASE['mainnet'])
    url = f'{base}/v1/blocks/{block_id}'
    try:
        resp = requests.get(url, timeout=15)
        if resp.status_code == 404:
            return None
        resp.raise_for_status()
        data = resp.json()
        if isinstance(data, list) and data:
            data = data[0]
        header = data.get('header', {})
        return {
            'height': header.get('height'),
            'timestamp': header.get('timestamp')
        }
    except requests.RequestException as e:
        print(f'[transaction_tracker] fetch_block_from_flow error: {e}', file=sys.stderr)
        return None
    except (json.JSONDecodeError, KeyError) as e:
        print(f'[transaction_tracker] parse block error: {e}', file=sys.stderr)
        return None


def update_transaction_with_flow_data(
    db_row: Dict[str, Any],
    supabase,
    transaction_logger,
    network: str = 'mainnet'
) -> bool:
    flow_tx_id = db_row.get('flow_transaction_id')
    if not flow_tx_id:
        return False
    tx_id = db_row.get('id')
    if not tx_id:
        return False
    flow_data = fetch_transaction_from_flow(flow_tx_id, network)
    if not flow_data:
        return False
    status = flow_data.get('status', '')
    if status == 'Sealed':
        block_id = flow_data.get('block_id')
        block_data = fetch_block_from_flow(block_id, network) if block_id else None
        block_height = None
        block_timestamp = None
        if block_data:
            h = block_data.get('height')
            block_height = int(h) if h is not None and str(h).isdigit() else None
            block_timestamp = block_data.get('timestamp')
        gas_used = None
        comp = flow_data.get('computation_used')
        if comp is not None and str(comp).isdigit():
            gas_used = int(comp)
        result_data = db_row.get('result_data') or {}
        if isinstance(result_data, str):
            try:
                result_data = json.loads(result_data) if result_data else {}
            except json.JSONDecodeError:
                result_data = {}
        if not isinstance(result_data, dict):
            result_data = {}
        result_data = {
            **result_data,
            'flow_transaction_id': flow_tx_id,
            'events': flow_data.get('events', []),
            'block_id': block_id,
            'status': 4,
            'statusString': 'SEALED'
        }
        transaction_logger.update_transaction_sealed(
            tx_id,
            block_height=block_height,
            block_timestamp=block_timestamp,
            gas_used=gas_used,
            result_data=result_data,
            execution_time_ms=db_row.get('execution_time_ms')
        )
        return True
    if status == 'Failed' or status == 'Expired':
        err = flow_data.get('error_message', '') or f'Transaction {status}'
        transaction_logger.update_transaction_failure(tx_id, err, db_row.get('execution_time_ms') or 0)
        return True
    return False


def run_tracker_cycle(
    supabase,
    transaction_logger,
    network: str = 'mainnet',
    limit: int = 50
) -> int:
    if not supabase:
        return 0
    try:
        resp = supabase.table('transactions').select('id,flow_transaction_id,execution_time_ms,result_data,network').not_.is_('flow_transaction_id', 'null').is_('block_height', 'null').limit(limit).execute()
        rows = resp.data or []
    except Exception as e:
        print(f'[transaction_tracker] query error: {e}', file=sys.stderr)
        return 0
    updated = 0
    for row in rows:
        row_network = row.get('network') or network
        try:
            if update_transaction_with_flow_data(row, supabase, transaction_logger, row_network):
                updated += 1
        except Exception as e:
            print(f'[transaction_tracker] update error for {row.get("id")}: {e}', file=sys.stderr)
    return updated
