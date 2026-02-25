# DerbyFish Flow CLI

Command-line tool for managing the derbyfish-flow suite: mission control, balances, transactions between any two wallets, and all operation types.

## Overview

The CLI supports two execution modes:

- **Standalone** (default) — Direct FlowPyAdapter + Supabase. No server required.
- **API** — HTTP client to the Flask app. Use when the API server is running.

## Installation

```bash
pip install -e .
```

Or run directly without installing:

```bash
PYTHONPATH=src/python python src/python/cli.py --help
```

## Quick Reference

```bash
derbyfish-flow-cli [OPTIONS] COMMAND [ARGS]
```

### Global Options

| Option | Env Var | Description |
|--------|---------|-------------|
| `--api URL` | `DERBYFISH_FLOW_API` | Use API mode (base URL, e.g. `http://localhost:5000`) |
| `--admin` | — | Use admin authentication |
| `--admin-secret TEXT` | `ADMIN_SECRET_KEY` | Admin secret key |
| `--jwt TEXT` | `DERBYFISH_JWT` | JWT token for user auth |
| `--user TEXT` | — | User auth_id for context |
| `--network [mainnet\|testnet]` | — | Flow network (default: mainnet) |

### Commands

| Command | Description |
|---------|-------------|
| `mission` | Mission control dashboard |
| `balance` | View BAIT, FLOW, or contract USDF balance |
| `tx` | Send tokens and swap |
| `admin` | Admin operations (mint, burn) |
| `vault` | Vault setup and reset |

---

## Mission Control

Dashboard with wallet count, total BAIT/FLOW, health, and recent transactions.

```bash
derbyfish-flow-cli mission
derbyfish-flow-cli mission --json
derbyfish-flow-cli --api http://localhost:5000 mission
```

**Standalone output:**
- Wallet count (from Supabase)
- Total BAIT across wallets
- Total FLOW across wallets
- Health (Flow access check)
- Recent transactions

**API mode output:**
- Health (GET /health)
- Background task count
- API URL

---

## Balance

View token balances for an address or auth_id.

```bash
derbyfish-flow-cli balance <address|auth_id>
derbyfish-flow-cli balance <address|auth_id> --flow
derbyfish-flow-cli balance <address|auth_id> --all
derbyfish-flow-cli balance --contract-usdf
derbyfish-flow-cli balance 0xed2202de80195438 --json
```

| Option | Description |
|--------|-------------|
| (none) | BAIT balance only |
| `--flow` | FLOW balance only |
| `--all` | BAIT and FLOW |
| `--contract-usdf` | Contract USDF balance (admin) |
| `--json` | Machine-readable output |

**Note:** `--flow` and `--all` require standalone mode. API mode supports BAIT and contract USDF only.

---

## Transactions (`tx`)

Send tokens between any two wallets or swap BAIT ↔ FUSD.

### Send BAIT

```bash
derbyfish-flow-cli tx send-bait --from <address|auth_id> --to <address|auth_id> --amount <amount>
```

### Send FUSD

```bash
derbyfish-flow-cli tx send-fusd --from <address|auth_id> --to <address|auth_id> --amount <amount>
```

Standalone only.

### Send FLOW

```bash
derbyfish-flow-cli tx send-flow --to <address|auth_id> --amount <amount>
derbyfish-flow-cli tx send-flow --from <address|auth_id> --to <address|auth_id> --amount <amount>
```

Without `--from`, uses mainnet-agfarms as payer. With `--from`, the specified wallet pays.

### Swap BAIT for FUSD

```bash
derbyfish-flow-cli tx swap-bait-for-fusd --from <address|auth_id> --amount <amount>
```

### Swap FUSD for BAIT

```bash
derbyfish-flow-cli tx swap-fusd-for-bait --from <address|auth_id> --amount <amount>
```

---

## Admin Operations

Requires `--admin` or `ADMIN_SECRET_KEY`.

### Mint BAIT

```bash
derbyfish-flow-cli --admin admin mint-bait --to <address|auth_id> --amount <amount>
```

### Burn BAIT

```bash
derbyfish-flow-cli --admin admin burn-bait --amount <amount>
derbyfish-flow-cli --admin admin burn-bait --amount <amount> --from-wallet <address|auth_id>
```

Without `--from-wallet`, burns from admin wallet. With `--from-wallet`, transfers from that wallet to admin, then burns.

### Mint FUSD

```bash
derbyfish-flow-cli --admin admin mint-fusd --to <address|auth_id> --amount <amount>
```

---

## Vault Operations

Create or reset vaults for an address. Requires the target wallet's private key (custodial).

### Create All Vaults

```bash
derbyfish-flow-cli vault create-all <address|auth_id>
```

Creates BAIT vault and capabilities.

### Create USDF Vault

```bash
derbyfish-flow-cli vault create-usdf <address|auth_id>
```

### Reset All Vaults

```bash
derbyfish-flow-cli vault reset-all <address|auth_id>
```

Resets BAIT vault and capabilities. Use with caution.

---

## Wallet Resolution

Addresses and auth_ids can be used interchangeably where a wallet is expected:

- **Flow address** — `0x` + 16 hex chars (e.g. `0xed2202de80195438`)
- **auth_id** — Supabase user UUID (e.g. `062c1061-ee58-4198-9cfa-f19551908910`)

Resolution order:
1. If 16-char hex → treat as Flow address
2. If UUID → Supabase `wallet` table by `auth_id`
3. If UUID → `flow-production.json` by account name

For transactions that need a private key (sender, vault ops), the CLI loads keys from:
- `flow/accounts/pkeys/<auth_id>.pkey`
- Supabase `wallet.flow_private_key`

---

## Authentication

### Admin Mode

```bash
derbyfish-flow-cli --admin ...
derbyfish-flow-cli --admin-secret YOUR_SECRET ...
export ADMIN_SECRET_KEY=...
derbyfish-flow-cli --admin ...
```

### User Mode (API)

```bash
derbyfish-flow-cli --jwt YOUR_SUPABASE_JWT ...
export DERBYFISH_JWT=...
derbyfish-flow-cli --api http://localhost:5000 tx send-bait ...
```

For `tx send-bait` in API mode, the JWT identifies the sender; `--from` is not used.

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role (wallet lookup) |
| `ADMIN_SECRET_KEY` | Admin operations |
| `DERBYFISH_FLOW_API` | Default API base URL |
| `DERBYFISH_JWT` | Default JWT for user auth |

Load from `.env` in the project root.

---

## Examples

### Mission control (standalone)

```bash
derbyfish-flow-cli mission
```

### Check admin wallet balance

```bash
derbyfish-flow-cli balance 0xed2202de80195438 --all
```

### Mint 1000 BAIT to a user

```bash
derbyfish-flow-cli --admin admin mint-bait --to 0x941947eccc6e9de4 --amount 1000
```

### Send BAIT between two custodial wallets

```bash
derbyfish-flow-cli tx send-bait --from 062c1061-ee58-4198-9cfa-f19551908910 --to 0x707efe31dd949d3b --amount 50
```

### API mode: check balance

```bash
derbyfish-flow-cli --api http://localhost:5000 --jwt $JWT balance
```

### JSON output for scripting

```bash
derbyfish-flow-cli balance 0xed2202de80195438 --json
derbyfish-flow-cli mission --json
```

---

## Operation Coverage

| Category | Operations |
|----------|------------|
| **Mission** | Dashboard (wallets, totals, health, recent tx) |
| **Balance** | BAIT, FLOW, contract USDF |
| **Send** | BAIT, FUSD, FLOW between any two wallets |
| **Swap** | BAIT ↔ FUSD |
| **Admin** | Mint/burn BAIT, mint FUSD |
| **Vault** | Create all, create USDF, reset all |
