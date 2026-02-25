from typing import Any, Dict, List, Optional

from supabase import Client


def _is_valid_wallet_id(wallet_id: Optional[str]) -> bool:
    if not wallet_id:
        return False
    import re
    uuid_regex = r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
    return bool(re.match(uuid_regex, wallet_id, re.I))


class TransactionLogger:
    def __init__(self, supabase_client: Optional[Client] = None):
        self.supabase = supabase_client

    def create_transaction(
        self,
        transaction_type: str,
        script_path: Optional[str] = None,
        transaction_path: Optional[str] = None,
        args: Optional[List[Any]] = None,
        proposer_wallet_id: Optional[str] = None,
        payer_wallet_id: Optional[str] = None,
        authorizer_wallet_ids: Optional[List[str]] = None,
        network: str = "mainnet",
    ) -> Optional[Dict[str, Any]]:
        if not self.supabase:
            return None
        try:
            transaction_data = {
                "transaction_type": transaction_type,
                "status": "pending",
                "network": network,
                "arguments": args or [],
                "logs": [
                    {
                        "level": "info",
                        "message": f"{transaction_type} execution started",
                        "timestamp": __import__("datetime").datetime.now().isoformat(),
                    }
                ],
            }
            if script_path:
                transaction_data["script_path"] = script_path
            if transaction_path:
                transaction_data["transaction_path"] = transaction_path
            if _is_valid_wallet_id(proposer_wallet_id):
                transaction_data["proposer_wallet_id"] = proposer_wallet_id
            if _is_valid_wallet_id(payer_wallet_id):
                transaction_data["payer_wallet_id"] = payer_wallet_id
            if authorizer_wallet_ids:
                valid_ids = [w for w in authorizer_wallet_ids if _is_valid_wallet_id(w)]
                if valid_ids:
                    transaction_data["authorizer_wallet_ids"] = valid_ids
            response = (
                self.supabase.table("transactions")
                .insert(transaction_data)
                .execute()
            )
            if response.data and len(response.data) > 0:
                return response.data[0]
            return None
        except Exception as e:
            if hasattr(e, "code") and e.code == "23503":
                return None
            if "foreign key constraint" in str(e).lower():
                return None
            raise

    def _append_log(
        self,
        transaction_id: str,
        log_entry: Dict[str, Any],
    ) -> List[Dict[str, Any]]:
        if not self.supabase:
            return []
        try:
            resp = (
                self.supabase.table("transactions")
                .select("logs")
                .eq("id", transaction_id)
                .single()
                .execute()
            )
            current = (resp.data or {}).get("logs") or []
            if not isinstance(current, list):
                current = []
            new_log = {**log_entry, "timestamp": __import__("datetime").datetime.now().isoformat()}
            return current + [new_log]
        except Exception:
            return [log_entry]

    def update_transaction(
        self,
        transaction_id: str,
        updates: Dict[str, Any],
    ) -> Optional[Dict[str, Any]]:
        if not self.supabase:
            return None
        try:
            response = (
                self.supabase.table("transactions")
                .update(updates)
                .eq("id", transaction_id)
                .execute()
            )
            if response.data and len(response.data) > 0:
                return response.data[0]
            return None
        except Exception:
            return None

    def update_transaction_success(
        self,
        transaction_id: str,
        result_data: Any,
        execution_time_ms: int,
    ) -> None:
        if not self.supabase:
            return
        logs = self._append_log(
            transaction_id,
            {"level": "info", "message": "Execution completed successfully", "execution_time_ms": execution_time_ms},
        )
        self.update_transaction(
            transaction_id,
            {"status": "executed", "result_data": result_data, "execution_time_ms": execution_time_ms, "logs": logs},
        )

    def update_transaction_failure(
        self,
        transaction_id: str,
        error_message: str,
        execution_time_ms: int,
    ) -> None:
        if not self.supabase:
            return
        logs = self._append_log(
            transaction_id,
            {"level": "error", "message": "Execution failed", "error": error_message, "execution_time_ms": execution_time_ms},
        )
        self.update_transaction(
            transaction_id,
            {"status": "failed", "error_message": error_message, "execution_time_ms": execution_time_ms, "logs": logs},
        )

    def update_transaction_submitted(
        self,
        transaction_id: str,
        flow_transaction_id: Optional[str] = None,
    ) -> None:
        if not self.supabase:
            return
        msg = "Transaction submitted to Flow network"
        if flow_transaction_id:
            msg += f" with ID {flow_transaction_id}"
        logs = self._append_log(transaction_id, {"level": "info", "message": msg})
        updates = {"status": "submitted", "logs": logs}
        if flow_transaction_id:
            updates["flow_transaction_id"] = flow_transaction_id
        self.update_transaction(transaction_id, updates)

    def update_transaction_sealed(
        self,
        transaction_id: str,
        block_height: Optional[int] = None,
        block_timestamp: Optional[str] = None,
        gas_used: Optional[int] = None,
        result_data: Optional[Any] = None,
        execution_time_ms: Optional[int] = None,
    ) -> None:
        if not self.supabase:
            return
        logs = self._append_log(
            transaction_id,
            {
                "level": "info",
                "message": "Transaction sealed successfully",
                "block_height": block_height,
                "block_timestamp": block_timestamp,
                "gas_used": gas_used,
                "execution_time_ms": execution_time_ms,
            },
        )
        updates = {"status": "sealed", "logs": logs}
        if block_height is not None:
            updates["block_height"] = block_height
        if block_timestamp is not None:
            updates["block_timestamp"] = block_timestamp
        if gas_used is not None:
            updates["gas_used"] = gas_used
        if result_data is not None:
            updates["result_data"] = result_data
        if execution_time_ms is not None:
            updates["execution_time_ms"] = execution_time_ms
        self.update_transaction(transaction_id, updates)
