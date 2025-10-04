# DerbyFish Flow CLI HTTP Wrapper

A Python Flask server that provides HTTP endpoints to execute Flow CLI commands in the background, making it easy to interact with your Flow blockchain project via REST API.

## Features

- **Script Execution**: Run Flow scripts via HTTP endpoints
- **Transaction Execution**: Send transactions via HTTP endpoints  
- **Background Processing**: Execute long-running commands asynchronously
- **Task Management**: Track and monitor background tasks
- **Multiple Networks**: Support for emulator, testnet, and mainnet
- **Error Handling**: Comprehensive error handling and response formatting

## Installation

1. Install Python dependencies:
```bash
pip install -r requirements.txt
```

2. Ensure Flow CLI is installed and configured in your system PATH

3. Make sure your Flow project is properly configured with `flow.json`

## Usage

### Starting the Server

```bash
python app.py
```

The server will start on `http://localhost:5000`

### API Endpoints

#### Scripts

- `GET /scripts/check-bait-balance?address=<address>` - Check BAIT balance for an address
- `GET /scripts/check-contract-vaults` - Check contract vaults
- `POST /scripts/create-vault-and-mint` - Create vault and mint tokens
- `POST /scripts/sell-bait` - Sell BAIT tokens
- `POST /scripts/test-bait-coin-admin` - Test BAIT coin admin functions

#### Transactions

- `POST /transactions/admin-burn-bait` - Admin burn BAIT tokens
- `POST /transactions/admin-mint-bait` - Admin mint BAIT tokens
- `POST /transactions/admin-mint-fusd` - Admin mint FUSD tokens
- `GET /transactions/check-contract-usdf-balance` - Check contract USDF balance
- `POST /transactions/create-all-vault` - Create all vaults
- `POST /transactions/create-usdf-vault` - Create USDF vault
- `POST /transactions/reset-all-vaults` - Reset all vaults
- `POST /transactions/send-bait` - Send BAIT tokens
- `POST /transactions/send-fusd` - Send FUSD tokens
- `POST /transactions/swap-bait-for-fusd` - Swap BAIT for FUSD
- `POST /transactions/swap-fusd-for-bait` - Swap FUSD for BAIT
- `POST /transactions/withdraw-contract-usdf` - Withdraw contract USDF

#### Background Tasks

- `POST /background/run-script` - Run a script in the background
- `POST /background/run-transaction` - Run a transaction in the background
- `GET /background/task/<task_id>` - Get task status
- `GET /background/tasks` - List all tasks

#### Utility

- `GET /` - API documentation
- `GET /health` - Health check

## Examples

### Check BAIT Balance

```bash
curl "http://localhost:5000/scripts/check-bait-balance?address=0x179b6b1cb6755e31"
```

### Send BAIT Tokens

```bash
curl -X POST "http://localhost:5000/transactions/send-bait" \
  -H "Content-Type: application/json" \
  -d '{
    "to_address": "0x44100f14f70e3f78",
    "amount": "100.0",
    "network": "emulator",
    "signer": "emulator-account"
  }'
```

### Run Script in Background

```bash
curl -X POST "http://localhost:5000/background/run-script" \
  -H "Content-Type: application/json" \
  -d '{
    "script_name": "checkBaitBalance.cdc",
    "args": ["0x179b6b1cb6755e31"],
    "network": "emulator"
  }'
```

### Check Task Status

```bash
curl "http://localhost:5000/background/task/<task_id>"
```

## Configuration

### Network Support

The API supports multiple Flow networks:
- `mainnet` (default)
- `testnet`
- `emulator`

### Signers

Default signers are configured in `flow.json`:
- `mainnet-agfarms` (default for mainnet)
- `emulator-account` (for emulator)

## Error Handling

All endpoints return JSON responses with the following structure:

```json
{
  "success": true/false,
  "stdout": "command output",
  "stderr": "error output",
  "returncode": 0,
  "command": "executed command"
}
```

For background tasks, additional fields include:
- `status`: "running" or "completed"
- `start_time`: ISO timestamp
- `end_time`: ISO timestamp (when completed)
- `duration`: execution time in seconds

## Development

The Flask server runs in debug mode by default. For production, consider:
- Setting `debug=False`
- Using a production WSGI server like Gunicorn
- Adding authentication and rate limiting
- Implementing proper logging

## License

This project is part of the DerbyFish Flow project.