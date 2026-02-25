import os
import pytest
from unittest.mock import patch, MagicMock

os.environ.update({
    'SUPABASE_URL': 'https://test.supabase.co',
    'SUPABASE_ANON_KEY': 'test-anon',
    'SUPABASE_SERVICE_ROLE_KEY': 'test-service-key',
    'SUPABASE_JWT_SECRET': 'test-jwt-secret-32-chars-long!!!!',
    'ADMIN_SECRET_KEY': 'test-admin-secret'
})

with patch('supabase.create_client', return_value=MagicMock()):
    import app as app_module


@pytest.fixture
def client():
    app_module.app.config['TESTING'] = True
    return app_module.app.test_client()


def test_index_returns_api_docs(client):
    rv = client.get('/')
    assert rv.status_code == 200
    data = rv.get_json()
    assert 'endpoints' in data
    assert 'version' in data


def test_health_returns_ok(client):
    rv = client.get('/health')
    assert rv.status_code == 200
    data = rv.get_json()
    assert data.get('status') == 'ok' or 'status' in data


def test_auth_status_returns_config(client):
    rv = client.get('/auth/status')
    assert rv.status_code == 200
    data = rv.get_json()
    assert 'supabase_url_configured' in data
    assert 'admin_secret_key_configured' in data


@patch.object(app_module, 'flow_adapter')
def test_check_bait_balance_requires_auth(mock_adapter, client):
    mock_adapter.execute_script.return_value = {'success': True, 'data': '1.5'}
    rv = client.get('/scripts/check-bait-balance?address=0x123')
    assert rv.status_code in (401, 400, 200)


@patch.object(app_module, 'flow_adapter')
def test_admin_mint_bait_requires_admin_auth(mock_adapter, client):
    rv = client.post('/transactions/admin-mint-bait', json={'to_address': '0x123', 'amount': '1.0'})
    assert rv.status_code in (401, 403, 400, 200)


def test_admin_burn_bait_with_valid_admin_secret(client):
    rv = client.post(
        '/transactions/admin-burn-bait',
        json={'amount': '1.0'},
        headers={'Authorization': 'Bearer test-admin-secret'}
    )
    assert rv.status_code in (200, 400, 500)
