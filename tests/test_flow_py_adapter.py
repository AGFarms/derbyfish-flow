from unittest.mock import patch, AsyncMock

import flow_py_adapter


def test_adapter_init_default_repo_root():
    adapter = flow_py_adapter.FlowPyAdapter()
    assert adapter.repo_root is not None
    assert adapter.flow_dir.endswith('flow')


def test_adapter_init_custom_repo_root():
    custom_root = '/custom/repo'
    adapter = flow_py_adapter.FlowPyAdapter(repo_root=custom_root)
    assert adapter.repo_root == custom_root
    assert adapter.flow_dir == f'{custom_root}/flow'


def test_execute_script_delegates_to_async():
    import asyncio
    adapter = flow_py_adapter.FlowPyAdapter(repo_root='/nonexistent')
    with patch.object(adapter, '_execute_script_async', new_callable=AsyncMock) as mock_async:
        mock_async.return_value = {'success': True, 'data': 42}
        result = adapter.execute_script('script.cdc', [], 'mainnet')
    mock_async.assert_called_once()
    assert result['success'] is True
    assert result['data'] == 42


def test_to_cadence_arg_address():
    from flow_py_adapter import _to_cadence_arg
    from flow_py_sdk.cadence import Address
    result = _to_cadence_arg('0x179b6b1cb6755e31')
    assert isinstance(result, Address)
    assert result.hex_with_prefix() == '0x179b6b1cb6755e31'


def test_to_cadence_arg_ufix64():
    from flow_py_adapter import _to_cadence_arg
    from flow_py_sdk.cadence import UFix64
    result = _to_cadence_arg('100.0')
    assert isinstance(result, UFix64)


def test_get_access_node():
    from flow_py_adapter import _get_access_node
    host, port = _get_access_node('mainnet')
    assert host == 'access.mainnet.nodes.onflow.org'
    assert port == 9000
    host, port = _get_access_node('testnet')
    assert host == 'access.devnet.nodes.onflow.org'
    assert port == 9000
    host, port = _get_access_node('emulator')
    assert host == '127.0.0.1'
    assert port == 3569
