# Flow Wallet Synchronization Service - Compact Blueprint

## Overview
Enterprise-grade Python daemon that maintains real-time synchronization between Supabase authentication system and Flow blockchain. Fetches all authenticated users and ensures each has proper BaitCoin vault setup, sufficient FLOW balance, and correct configuration files.

## Core Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Supabase DB   │◄──►│  Sync Service    │◄──►│  Flow Network   │
│ • auth.users     │    │ • Service Loop   │    │ • Balance Query │
│ • wallet table  │    │ • Rate Limiting  │    │ • Vault Ops     │
│ • Auth Records  │    │ • Thread Mgmt    │    │ • Transactions  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  File System    │    │  Configuration   │    │  Service Accts  │
│ • Private Keys  │    │ • flow.json      │    │ • 9 Funding Accts│
│ • pkeys/*.pkey  │    │ • Production     │    │ • Round-Robin   │
│ • Backups       │    │ • Account Configs│    │ • Rate Limits   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Service Workflow

### 1. Initialization Sequence
```
STARTUP → ENV_VALIDATION → DB_CONNECTION → FLOW_CONFIG → ACCOUNT_SETUP → INITIAL_SYNC → SERVICE_LOOP
```

### 2. Wallet Synchronization Pipeline
```
USER_FETCH → WALLET_VALIDATION → BLOCKCHAIN_STATE_CHECK → VAULT_MANAGEMENT → FUNDING_CHECK → CONFIG_GENERATION
```

**Detailed Process:**
1. **User Data Retrieval**: Paginated fetching from Supabase auth system and `wallet` table (1000 records/page)
2. **Wallet Generation**: Creates new Flow wallets for users without existing wallets
3. **Blockchain State Check**: Verifies FLOW balance and BaitCoin vault status
4. **Vault Management**: Creates missing vaults, publishes balance capabilities
5. **FLOW Funding**: Funds wallets below 0.075 FLOW threshold with 0.1 FLOW
6. **Configuration Generation**: Updates `flow-production.json` with wallet configs

## Key Components

### Database Integration
- **Supabase Client**: Service role authentication with elevated privileges
- **User Fetching**: Uses Supabase Admin API (`auth.admin.list_users()`) to fetch all authenticated users
- **User Data**: Retrieves user ID, email, and creation timestamp from auth system
- **Pagination**: Handles large datasets efficiently (1000 records per page)
- **Error Recovery**: Automatic retry mechanisms for transient failures

### Flow Blockchain Interface
- **Script Execution**: Real-time balance queries via Cadence scripts
- **Transaction Broadcasting**: Automated funding and vault creation
- **Rate Limiting**: 5 RPS for scripts, 50 RPS for transactions
- **Multi-Account Management**: 9 funding accounts for load distribution

### Threading & Concurrency
- **Single-Threaded Processing**: Prevents rate limit violations
- **Account Assignment**: Round-robin distribution across funding accounts
- **Thread-Safe Statistics**: Atomic counters for operational metrics
- **Resource Locking**: Prevents race conditions

## Configuration Management

### Environment Variables
```bash
SYNC_INTERVAL=300              # Synchronization interval (seconds)
SUPABASE_URL=...              # Database connection URL
SUPABASE_SERVICE_ROLE_KEY=... # Database service role key
NETWORK=mainnet               # Flow network (mainnet/testnet)
```

### Rate Limiting Parameters
```python
script_interval = 0.2         # 200ms between script calls (5 RPS)
transaction_interval = 0.02   # 20ms between transaction calls (50 RPS)
```

### Funding Thresholds
```python
flow_funding_threshold = 0.075  # Minimum FLOW balance
flow_funding_amount = 0.1       # Amount to fund when below threshold
```

## File System Structure

### Private Key Management
```
flow/accounts/pkeys/
├── auth_id_1.pkey
├── auth_id_2.pkey
└── ...
```

### Configuration Files
```
flow/accounts/
├── flow-production.json      # Main configuration
├── flow-production.json.backup  # Backup before updates
└── pkeys/                   # Private key storage
```

## Operational Metrics

### Statistics Tracking
```python
stats = {
    'total_wallets': 0,           # Total wallets processed
    'synced_wallets': 0,          # Successfully synchronized
    'corrupted_wallets': 0,       # Wallets with missing data
    'wallets_created': 0,         # New wallets generated
    'vaults_created': 0,          # BaitCoin vaults created
    'vaults_already_exist': 0,    # Existing vaults found
    'flow_balance_checks': 0,     # FLOW balance queries
    'flow_funding_needed': 0,     # Wallets requiring funding
    'flow_funding_success': 0,    # Successful funding operations
    'flow_funding_errors': 0      # Failed funding operations
}
```

## Error Handling & Recovery

### Error Categories
- **Rate Limiting**: Automatic retry with exponential backoff
- **Network Errors**: Graceful degradation, continues with other wallets
- **Data Corruption**: Logs and skips corrupted wallet records
- **Blockchain State**: Attempts vault creation/capability publishing

### Recovery Mechanisms
- **Graceful Degradation**: Continues operation despite individual failures
- **Error Classification**: Distinguishes between different error types
- **Retry Logic**: Exponential backoff for transient failures
- **Comprehensive Logging**: Detailed error tracking with context

## Service Lifecycle

### Startup Sequence
1. **Signal Handler Registration**: SIGTERM/SIGINT for graceful shutdown
2. **Directory Validation**: Ensures `flow/` directory structure exists
3. **Database Connection**: Establishes Supabase client
4. **Initial Sync**: Performs first synchronization cycle
5. **Service Loop**: Enters continuous operation

### Shutdown Sequence
1. **Signal Reception**: Handles termination signals gracefully
2. **Current Operation Completion**: Finishes active sync cycle
3. **Resource Cleanup**: Closes database connections
4. **State Persistence**: Saves final statistics
5. **Process Termination**: Exits cleanly

## Cadence Scripts & Transactions

### Scripts Used
- `checkFlowBalance.cdc`: Queries FLOW token balance
- `checkBaitBalance.cdc`: Queries BaitCoin balance and vault status

### Transactions Used
- `fundWallet.cdc`: Funds wallets with FLOW tokens
- `createAllVault.cdc`: Creates BaitCoin vaults
- `publishBaitBalance.cdc`: Publishes balance capabilities

## Performance Optimization

### Scalability Features
- **Horizontal Scaling**: Multiple service instances
- **Database Optimization**: Indexed queries, connection pooling
- **Network Optimization**: Efficient API usage patterns
- **Resource Management**: Memory and CPU optimization

### Monitoring Capabilities
- **Real-time Metrics**: Live synchronization status
- **Historical Trends**: Performance over time
- **Error Analytics**: Detailed error categorization
- **Resource Utilization**: Database and network usage

## Security Considerations

### Access Control
- **Service Role Authentication**: Elevated database privileges
- **Private Key Management**: Secure file system storage
- **Network Security**: Encrypted communication with Flow network
- **Audit Logging**: Comprehensive operation tracking

### Data Protection
- **Sensitive Data Handling**: Secure storage of private keys
- **Transmission Security**: Encrypted API communications
- **Access Logging**: Detailed audit trails
- **Backup Procedures**: Regular configuration backups

## Usage

### Running the Service
```bash
python3 syncWalletsService.py
```

### Service Control
- **Graceful Shutdown**: SIGTERM or SIGINT signals
- **Configuration**: Environment variables
- **Monitoring**: Console output with detailed statistics
- **Logging**: Comprehensive error and operation tracking

## Key Features

- **Real-time Synchronization**: Continuous wallet state management
- **Automated Funding**: Ensures sufficient FLOW balance for operations
- **Vault Management**: Creates and manages BaitCoin vaults
- **Rate Limiting**: Compliant with Flow network constraints
- **Error Recovery**: Robust error handling and recovery mechanisms
- **Multi-threading**: Efficient processing with thread-safe operations
- **Configuration Management**: Dynamic Flow CLI configuration generation
- **Monitoring**: Comprehensive operational metrics and statistics

---

*This service provides the critical infrastructure for maintaining consistency between the DerbyFish ecosystem's database and Flow blockchain network, ensuring reliable wallet management and blockchain operations.*