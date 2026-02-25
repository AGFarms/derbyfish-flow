from typing import Any, Dict, List, Optional, Protocol


class FlowAdapter(Protocol):
    def execute_script(
        self,
        script_path: str,
        args: Optional[List[Any]] = None,
        network: str = "mainnet",
    ) -> Dict[str, Any]:
        ...

    def send_transaction(
        self,
        transaction_path: str,
        args: Optional[List[Any]] = None,
        roles: Optional[Dict[str, Any]] = None,
        network: str = "mainnet",
        proposer_wallet_id: Optional[str] = None,
        payer_wallet_id: Optional[str] = None,
        authorizer_wallet_ids: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        ...

    def send_transaction_with_private_key(
        self,
        transaction_path: str,
        args: Optional[List[Any]] = None,
        roles: Optional[Dict[str, Any]] = None,
        network: str = "mainnet",
        private_keys: Optional[Dict[str, str]] = None,
        proposer_wallet_id: Optional[str] = None,
        payer_wallet_id: Optional[str] = None,
        authorizer_wallet_ids: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        ...

    def get_transaction(
        self,
        transaction_id: str,
        network: str = "mainnet",
    ) -> Dict[str, Any]:
        ...

    def get_account(
        self,
        address: str,
        network: str = "mainnet",
    ) -> Dict[str, Any]:
        ...
