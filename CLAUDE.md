# CLAUDE.md - derbyfish-flow

## Overview

Flow blockchain API service for DerbyFish. Handles custodial wallet creation, Fish Card NFT minting (FishCardV1), BaitCoin fungible token operations, and all on-chain interactions. Provides both a Flask REST API and a CLI tool.

## Stack

- **Framework**: Flask 2.3
- **Language**: Python 3.11+ (requires >= 3.10)
- **Blockchain**: Flow SDK (`flow-py-sdk`), Cadence smart contracts
- **Backend**: Supabase Python SDK
- **Auth**: PyJWT for Supabase JWT verification
- **Crypto**: `cryptography` library for wallet key encryption
- **CLI**: Click + Rich
- **Testing**: pytest + pytest-cov
- **Packaging**: setuptools (pyproject.toml)

## Dev Setup

```bash
cd derbyfish-flow
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
PYTHONPATH=src/python python src/python/app.py    # Flask dev server (http://localhost:5000)
```

Required environment variables (in `.env`):
```
SUPABASE_URL=https://db.derby.fish
SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
SUPABASE_JWT_SECRET=...
ADMIN_SECRET_KEY=...
WALLET_ENCRYPTION_KEY=...
```

## Testing

```bash
pytest tests -v                  # Run all tests
pytest tests -v --cov            # With coverage
```

## Key Files

| File | Purpose |
|------|---------|
| `src/python/app.py` | Flask application entry point and route definitions |
| `src/python/flow_py_adapter.py` | Flow blockchain SDK adapter |
| `src/python/wallet_crypto.py` | Wallet private key encryption/decryption |
| `src/python/transaction_logger.py` | Transaction logging to Supabase |
| `src/python/syncWalletsService.py` | Wallet sync daemon service |
| `src/python/cli.py` | CLI entry point |
| `flow/cadence/contracts/FishCardV1.cdc` | Fish Card NFT contract (Cadence) |
| `flow/cadence/contracts/BaitCoin.cdc` | BaitCoin fungible token contract (Cadence) |
| `flow/cadence/contracts/RankboardV1.cdc` | Rankboard contract (Cadence) |
| `flow/cadence/transactions/` | Cadence transaction scripts |
| `flow/cadence/scripts/` | Cadence read-only scripts |
| `tests/` | pytest test suite |

## CLI

```bash
pip install -e .                     # Install CLI locally
derbyfish-flow-cli --help           # Show available commands
```

## Environment

This service uses `.env` for local development. Dev Supabase: `https://db.derby.fish`

## Production Safety

See org root CLAUDE.md. NEVER use `tdecpfvclvqcqjfyxgnn.supabase.co` in development. NEVER commit `.env` files. NEVER commit private keys (`*.pkey` files) or wallet encryption keys.

## Build & Deploy

- **Docker**: Python 3.11-slim base. Includes startup health check.
  ```bash
  docker-compose up --build     # Runs API on port 5000, plus sync service
  ```
- **Images**: `farmera/derbyfish-flow:$TAG` (API), `farmera/derbyfish-flow-sync:$TAG` (sync daemon)
- **Health check**: `GET /health` on port 5000
- **Volumes**: Production mounts private keys and flow-production.json from host
- **CI**: Builds are pushed to Docker Hub, deployed to production server
