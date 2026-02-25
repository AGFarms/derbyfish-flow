# Flow Wallet Synchronization Service - Comprehensive Documentation

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
│ • Private Keys  │    │ • flow.json      │    │ • mainnet-agfarms│
│ • pkeys/*.pkey  │    │ • Production     │    │ • Single Account│
│ • Backups       │    │ • Account Configs│    │ • Rate Limits   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Data Flow Architecture

```
STARTUP → INIT → FETCH_USERS → FETCH_WALLETS → PROCESS_WALLETS → UPDATE_CONFIG → LOOP
    │        │         │            │              │                │           │
    ▼        ▼         ▼            ▼              ▼                ▼           ▼
SIGNALS → ENV_VAL → SUPABASE → DATABASE → BLOCKCHAIN → FILESYSTEM → STATS → SHUTDOWN
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

## Complete Function Reference

### Core Service Functions

#### `__init__(self)`
**Purpose**: Initialize the WalletSyncService with all required components and state
**Flow**: 
- Sets up file system paths (flow_dir, accounts_dir, pkeys_dir, production_file)
- Initializes FlowPyAdapter for blockchain operations
- Creates statistics tracking dictionary with thread-safe locks
- Configures thread management for single service account
- Sets up rate limiting parameters (0.2s scripts, 0.02s transactions)
- Registers signal handlers for graceful shutdown
**Parameters**: None
**Returns**: None
**Thread Safety**: Constructor - single-threaded initialization

#### `_signal_handler(self, signum, frame)`
**Purpose**: Handle system signals (SIGTERM/SIGINT) for graceful shutdown
**Flow**: 
- Sets running flag to False
- Sets shutdown_event to signal all threads to stop
- Prints shutdown message
**Parameters**: 
- `signum`: Signal number
- `frame`: Current stack frame
**Returns**: None
**Thread Safety**: Thread-safe signal handling

#### `_get_thread_account(self, thread_id)`
**Purpose**: Get the service account to use for funding operations
**Flow**: 
- Always returns "mainnet-agfarms" (single service account)
- Thread-safe access via thread_lock
**Parameters**: 
- `thread_id`: Thread identifier (unused in current implementation)
**Returns**: `str` - Service account name
**Thread Safety**: Protected by thread_lock

#### `_rate_limit(self, request_type)`
**Purpose**: Enforce rate limiting for Flow network requests
**Flow**: 
- Checks time since last request of same type
- Sleeps if necessary to maintain rate limits
- Updates last request time
- Respects shutdown event during sleep
**Parameters**: 
- `request_type`: 'script' or 'transaction'
**Returns**: `bool` - True if request can proceed, False if shutdown requested
**Thread Safety**: Protected by rate_limit_lock

### Database Integration Functions

#### `_init_supabase(self)`
**Purpose**: Initialize Supabase client with service role authentication
**Flow**: 
- Validates SUPABASE_URL and SUPABASE_SERVICE_KEY environment variables
- Creates Supabase client with elevated privileges
- Returns configured client
**Parameters**: None
**Returns**: `Client` - Configured Supabase client
**Thread Safety**: Single-threaded initialization

#### `_fetch_users(self)`
**Purpose**: Fetch all users from Supabase auth system with pagination
**Flow**: 
- Uses Supabase Admin API to list users with pagination (1000 per page)
- Handles different response formats (list, dict with data, gotrue.types.User)
- Transforms user data to standardized format
- Continues until no more users found
- Returns list of user dictionaries
**Parameters**: None
**Returns**: `List[Dict]` - List of user records with auth_id, email, created_at
**Thread Safety**: Single-threaded database operation

#### `_fetch_wallets(self)`
**Purpose**: Fetch existing wallet records from database with pagination
**Flow**: 
- Queries wallet table with pagination (1000 records per page)
- Continues until no more records found
- Returns all wallet records
**Parameters**: None
**Returns**: `List[Dict]` - List of wallet records from database
**Thread Safety**: Single-threaded database operation

### File System Functions

#### `_load_production_config(self)`
**Purpose**: Load current flow-production.json configuration
**Flow**: 
- Checks if production file exists
- Loads and parses JSON content
- Returns configuration dictionary or None if error
**Parameters**: None
**Returns**: `Dict` or `None` - Configuration dictionary or None if error
**Thread Safety**: Single-threaded file operation

#### `_load_private_key(self, auth_id)`
**Purpose**: Load private key from pkey file for given auth_id
**Flow**: 
- Constructs pkey file path: `pkeys/{auth_id}.pkey`
- Reads file content and strips whitespace
- Returns private key string or None if error
**Parameters**: 
- `auth_id`: User authentication ID
**Returns**: `str` or `None` - Private key or None if error
**Thread Safety**: Single-threaded file operation

#### `_ensure_pkey_file(self, auth_id, private_key)`
**Purpose**: Ensure private key file exists for given auth_id
**Flow**: 
- Constructs pkey file path
- Creates pkeys directory if it doesn't exist
- Writes private key to file if file doesn't exist
- Returns True on success
**Parameters**: 
- `auth_id`: User authentication ID
- `private_key`: Private key string to write
**Returns**: `bool` - True on success
**Thread Safety**: Single-threaded file operation

### Wallet Management Functions

#### `_generate_wallet(self, auth_id)`
**Purpose**: Generate a new Flow wallet for the given auth_id
**Flow**: 
- Generates random 32-byte private key using secrets module
- Creates simplified Flow address (placeholder implementation)
- Saves private key to pkey file
- Creates wallet record in database
- Returns wallet record or None if error
**Parameters**: 
- `auth_id`: User authentication ID
**Returns**: `Dict` or `None` - Wallet record or None if error
**Thread Safety**: Single-threaded operation

#### `_ensure_wallet_record_exists(self, auth_id, flow_address)`
**Purpose**: Ensure wallet record exists in database for given auth_id
**Flow**: 
- Queries wallet table for existing record
- Returns first matching record
**Parameters**: 
- `auth_id`: User authentication ID
- `flow_address`: Flow address (unused in current implementation)
**Returns**: `Dict` or `None` - Wallet record or None if not found
**Thread Safety**: Single-threaded database operation

#### `_validate_wallet(self, wallet)`
**Purpose**: Validate wallet record has all required fields
**Flow**: 
- Checks for required fields: auth_id, flow_address, flow_private_key, flow_public_key
- Returns True if all fields present, False otherwise
**Parameters**: 
- `wallet`: Wallet record dictionary
**Returns**: `bool` - True if valid, False otherwise
**Thread Safety**: Single-threaded validation

### Blockchain Interaction Functions

#### `_check_flow_balance(self, flow_address)`
**Purpose**: Check FLOW token balance for given address
**Flow**: 
- Ensures address has 0x prefix
- Executes checkFlowBalance.cdc script via FlowPyAdapter
- Parses balance from script result
- Returns balance as float
**Parameters**: 
- `flow_address`: Flow address to check
**Returns**: `float` - FLOW balance
**Thread Safety**: Single-threaded blockchain operation
**Rate Limiting**: Enforced via _rate_limit('script')

#### `_fund_wallet(self, flow_address, amount=0.1, thread_id=None)`
**Purpose**: Fund wallet with FLOW tokens
**Flow**: 
- Gets thread account for funding
- Ensures address has 0x prefix
- Sends fundWallet.cdc transaction via FlowPyAdapter
- Returns success status
**Parameters**: 
- `flow_address`: Flow address to fund
- `amount`: Amount to fund (default 0.1)
- `thread_id`: Thread identifier (optional)
**Returns**: `bool` - True if successful, False otherwise
**Thread Safety**: Single-threaded blockchain operation
**Rate Limiting**: Enforced via _rate_limit('transaction')

#### `_check_bait_vault(self, flow_address)`
**Purpose**: Check if BaitCoin vault exists for given address
**Flow**: 
- Ensures address has 0x prefix
- Executes checkBaitBalance.cdc script
- Returns success status (vault exists if successful)
**Parameters**: 
- `flow_address`: Flow address to check
**Returns**: `bool` - True if vault exists, False otherwise
**Thread Safety**: Single-threaded blockchain operation
**Rate Limiting**: Enforced via _rate_limit('script')

#### `_check_bait_balance(self, flow_address)`
**Purpose**: Check BaitCoin balance for given address
**Flow**: 
- Ensures address has 0x prefix
- Executes checkBaitBalance.cdc script
- Parses balance from result (handles int, float, string types)
- Returns balance as float
**Parameters**: 
- `flow_address`: Flow address to check
**Returns**: `float` - BaitCoin balance
**Thread Safety**: Single-threaded blockchain operation
**Rate Limiting**: Enforced via _rate_limit('script')

#### `_publish_bait_balance_capability(self, flow_address, auth_id, thread_id=None)`
**Purpose**: Publish BaitCoin balance capability for given address
**Flow**: 
- Gets thread account for payer
- Sends publishBaitBalance.cdc transaction
- Returns success status
**Parameters**: 
- `flow_address`: Flow address (unused in current implementation)
- `auth_id`: User authentication ID
- `thread_id`: Thread identifier (optional)
**Returns**: `bool` - True if successful, False otherwise
**Thread Safety**: Single-threaded blockchain operation
**Rate Limiting**: Enforced via _rate_limit('transaction')

#### `_create_bait_vault(self, flow_address, auth_id, thread_id=None)`
**Purpose**: Create BaitCoin vault for given address
**Flow**: 
- Gets thread account for payer
- Sends createAllVault.cdc transaction
- Returns success status
**Parameters**: 
- `flow_address`: Flow address to create vault for
- `auth_id`: User authentication ID
- `thread_id`: Thread identifier (optional)
**Returns**: `bool` - True if successful, False otherwise
**Thread Safety**: Single-threaded blockchain operation
**Rate Limiting**: Enforced via _rate_limit('transaction')

### Configuration Management Functions

#### `_update_production_config(self, wallet_config)`
**Purpose**: Update flow-production.json with single wallet config (thread-safe)
**Flow**: 
- Acquires file lock for thread safety
- Loads existing configuration or creates new one
- Updates accounts section with new wallet config
- Creates backup of existing file
- Writes updated configuration
- Returns success status
**Parameters**: 
- `wallet_config`: Dictionary of wallet configurations to add
**Returns**: `bool` - True if successful, False otherwise
**Thread Safety**: Protected by file_lock

#### `_save_production_config(self, config)`
**Purpose**: Save complete production config (used for full sync)
**Flow**: 
- Acquires file lock for thread safety
- Creates backup of existing file
- Writes complete configuration
- Returns success status
**Parameters**: 
- `config`: Complete configuration dictionary
**Returns**: `bool` - True if successful, False otherwise
**Thread Safety**: Protected by file_lock

### Statistics and Utility Functions

#### `_reset_stats(self)`
**Purpose**: Reset all statistics counters to zero
**Flow**: 
- Acquires stats lock for thread safety
- Iterates through all stats keys and sets to 0
**Parameters**: None
**Returns**: None
**Thread Safety**: Protected by stats_lock

### Main Processing Functions

#### `_process_wallet(self, wallet)`
**Purpose**: Process individual wallet through complete synchronization pipeline
**Flow**: 
- Validates wallet record exists in database
- Validates wallet has required fields
- Ensures private key file exists
- Checks FLOW balance and funds if below threshold
- Checks BaitCoin balance and creates vault/capability if needed
- Updates production config with wallet configuration
- Updates statistics counters
- Returns wallet configuration
**Parameters**: 
- `wallet`: Wallet record dictionary
**Returns**: `Dict` or `None` - Wallet configuration or None if error
**Thread Safety**: Updates stats with locks, calls thread-safe functions

#### `_create_production_config(self, wallets)`
**Purpose**: Create complete production configuration from wallet list
**Flow**: 
- Uses ThreadPoolExecutor with up to 3 workers
- Submits each wallet to _process_wallet
- Collects results and builds complete configuration
- Returns complete configuration dictionary
**Parameters**: 
- `wallets`: List of wallet records
**Returns**: `Dict` - Complete production configuration
**Thread Safety**: Uses thread pool with individual wallet processing

#### `sync_wallets(self)`
**Purpose**: Main synchronization function that orchestrates entire process
**Flow**: 
- Validates flow directory exists
- Initializes Supabase connection
- Fetches all users from auth system
- Fetches existing wallets from database
- Generates new wallets for users without existing wallets
- Processes all wallets through _create_production_config
- Prints sync summary with statistics
- Returns success status
**Parameters**: None
**Returns**: `bool` - True if successful, False otherwise
**Thread Safety**: Orchestrates thread-safe operations

#### `run_service(self)`
**Purpose**: Main service loop that runs continuous synchronization
**Flow**: 
- Prints startup information
- Performs initial sync
- Enters main loop with SYNC_INTERVAL
- Resets statistics before each sync
- Handles graceful shutdown on signals
- Continues until running flag is False
**Parameters**: None
**Returns**: None
**Thread Safety**: Main service loop, coordinates all operations

#### `main()`
**Purpose**: Entry point for the service
**Flow**: 
- Creates WalletSyncService instance
- Calls run_service to start the service
**Parameters**: None
**Returns**: None
**Thread Safety**: Single-threaded entry point

## Detailed Workflow Documentation

### Service Lifecycle Workflows

#### 1. Service Startup Workflow
```
main() → WalletSyncService.__init__() → run_service() → sync_wallets() → SERVICE_LOOP
    │              │                        │                │              │
    ▼              ▼                        ▼                ▼              ▼
ENTRY_POINT → INITIALIZATION → STARTUP_MSG → INITIAL_SYNC → CONTINUOUS_LOOP
```

**Startup Sequence:**
1. **Entry Point**: `main()` creates service instance
2. **Initialization**: `__init__()` sets up all components and state
3. **Service Start**: `run_service()` begins main service loop
4. **Initial Sync**: First synchronization cycle
5. **Continuous Loop**: Regular sync cycles with interval timing

#### 2. Wallet Synchronization Workflow
```
sync_wallets() → _fetch_users() → _fetch_wallets() → _create_production_config() → _process_wallet()
      │                │                │                        │                    │
      ▼                ▼                ▼                        ▼                    ▼
VALIDATE_DIR → FETCH_AUTH_USERS → FETCH_DB_WALLETS → THREAD_POOL_EXEC → INDIVIDUAL_PROCESSING
```

**Synchronization Steps:**
1. **Directory Validation**: Ensures flow directory exists
2. **Database Connection**: Initializes Supabase client
3. **User Fetching**: Gets all authenticated users with pagination
4. **Wallet Fetching**: Gets existing wallet records from database
5. **Wallet Generation**: Creates new wallets for users without existing ones
6. **Parallel Processing**: Uses thread pool to process wallets concurrently
7. **Configuration Update**: Updates flow-production.json with results

#### 3. Individual Wallet Processing Workflow
```
_process_wallet() → _validate_wallet() → _check_flow_balance() → _check_bait_balance() → _update_production_config()
        │                    │                    │                      │                        │
        ▼                    ▼                    ▼                      ▼                        ▼
WALLET_VALIDATION → FIELD_VALIDATION → FLOW_BALANCE_CHECK → BAIT_VAULT_CHECK → CONFIG_UPDATE
        │                    │                    │                      │                        │
        ▼                    ▼                    ▼                      ▼                        ▼
DB_RECORD_CHECK → REQUIRED_FIELDS → BALANCE_QUERY → VAULT_STATUS → FILE_UPDATE
```

**Wallet Processing Steps:**
1. **Database Validation**: Ensures wallet record exists in database
2. **Field Validation**: Checks for required wallet fields
3. **Private Key Management**: Ensures pkey file exists
4. **FLOW Balance Check**: Queries blockchain for FLOW balance
5. **BaitCoin Vault Check**: Determines vault existence and capability status
6. **Vault Management**: Creates vaults and publishes capabilities as needed
7. **FLOW Funding**: Funds wallets below threshold
8. **Configuration Update**: Updates production config with wallet details

#### 4. BaitCoin Vault Management Workflow
```
_check_bait_balance() → [SUCCESS] → VAULT_EXISTS
        │
        ▼ [FAILURE]
_publish_bait_balance_capability() → [SUCCESS] → CAPABILITY_PUBLISHED
        │
        ▼ [FAILURE]
_create_bait_vault() → [SUCCESS] → VAULT_CREATED
        │
        ▼ [FAILURE]
VAULT_CREATION_ERROR
```

**Vault Management Logic:**
1. **Initial Check**: Attempt to read BaitCoin balance
2. **Success Path**: Vault exists and capability is published
3. **Capability Missing**: Publish balance capability
4. **Vault Missing**: Create BaitCoin vault
5. **Error Handling**: Log errors and continue with next wallet

#### 5. FLOW Funding Workflow
```
_check_flow_balance() → [BALANCE < 0.075] → _fund_wallet() → [SUCCESS/FAILURE]
        │                        │                │
        ▼                        ▼                ▼
BALANCE_QUERY → THRESHOLD_CHECK → FUNDING_TX → RESULT_LOG
```

**Funding Logic:**
1. **Balance Check**: Query current FLOW balance
2. **Threshold Check**: Compare against 0.075 FLOW minimum
3. **Funding Decision**: Fund with 0.1 FLOW if below threshold
4. **Transaction Execution**: Send funding transaction via service account
5. **Result Tracking**: Update statistics based on success/failure

#### 6. Configuration Management Workflow
```
_update_production_config() → _load_production_config() → BACKUP_CREATE → CONFIG_UPDATE → FILE_WRITE
        │                            │                        │                │              │
        ▼                            ▼                        ▼                ▼              ▼
FILE_LOCK_ACQUIRE → EXISTING_CONFIG → BACKUP_FILE → MERGE_CONFIG → ATOMIC_WRITE
```

**Configuration Update Steps:**
1. **File Lock**: Acquire exclusive access to configuration file
2. **Load Existing**: Read current configuration or create new structure
3. **Backup Creation**: Rename existing file to .backup
4. **Configuration Merge**: Add new wallet configurations
5. **Atomic Write**: Write updated configuration to file
6. **Lock Release**: Release file lock for other operations

### State Transition Diagrams

#### Service State Machine
```
[STOPPED] → [STARTING] → [RUNNING] → [SYNCING] → [RUNNING] → [STOPPING] → [STOPPED]
     ↑           │           │           │           │           │           │
     │           ▼           ▼           ▼           ▼           ▼           │
     └──── [ERROR] ←──── [ERROR] ←──── [ERROR] ←──── [ERROR] ←──── [ERROR] ──┘
```

#### Wallet State Machine
```
[NO_WALLET] → [WALLET_CREATED] → [VALIDATING] → [SYNCED] → [SYNCED]
     │              │                │             │          │
     ▼              ▼                ▼             ▼          ▼
[ERROR] ←──── [ERROR] ←──── [ERROR] ←──── [ERROR] ←──── [ERROR]
```

#### Vault State Machine
```
[NO_VAULT] → [VAULT_CREATED] → [CAPABILITY_PUBLISHED] → [FULLY_SYNCED]
     │             │                    │                      │
     ▼             ▼                    ▼                      ▼
[ERROR] ←──── [ERROR] ←──── [ERROR] ←──── [ERROR]
```

### Error Handling Workflows

#### Database Error Handling
```
DATABASE_OPERATION → [SUCCESS] → CONTINUE
        │
        ▼ [FAILURE]
ERROR_LOG → [RETRYABLE] → RETRY_WITH_BACKOFF
        │
        ▼ [NON_RETRYABLE]
SKIP_OPERATION → CONTINUE_WITH_NEXT
```

#### Blockchain Error Handling
```
BLOCKCHAIN_OPERATION → [SUCCESS] → CONTINUE
        │
        ▼ [FAILURE]
ERROR_LOG → [RATE_LIMIT] → WAIT_AND_RETRY
        │
        ▼ [NETWORK_ERROR]
SKIP_WALLET → CONTINUE_WITH_NEXT
        │
        ▼ [INSUFFICIENT_FUNDS]
LOG_ERROR → CONTINUE_WITH_NEXT
```

#### File System Error Handling
```
FILE_OPERATION → [SUCCESS] → CONTINUE
        │
        ▼ [FAILURE]
ERROR_LOG → [PERMISSION_ERROR] → EXIT_SERVICE
        │
        ▼ [DISK_FULL]
LOG_ERROR → CONTINUE_WITH_NEXT
        │
        ▼ [FILE_LOCKED]
WAIT_AND_RETRY
```

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
- **Single Account Management**: Uses mainnet-agfarms service account for all operations

### Threading & Concurrency
- **Thread Pool Processing**: Up to 3 concurrent wallet processing threads
- **Thread-Safe Operations**: All shared resources protected with locks
- **Thread-Safe Statistics**: Atomic counters for operational metrics
- **Resource Locking**: Prevents race conditions on file and database operations

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

### Thread Pool Configuration
```python
max_workers = min(3, len(wallets))  # Up to 3 concurrent threads
```

### Service Account Configuration
```python
funder_accounts = ["mainnet-agfarms"]  # Single service account for funding
```

## File System Structure

### Private Key Management
```
flow/accounts/pkeys/
├── auth_id_1.pkey          # User 1 private key
├── auth_id_2.pkey          # User 2 private key
└── ...                     # Additional user private keys
```

### Configuration Files
```
flow/accounts/
├── flow-production.json         # Main configuration file
├── flow-production.json.backup  # Backup before updates
└── pkeys/                      # Private key storage directory
    ├── auth_id_1.pkey
    ├── auth_id_2.pkey
    └── ...
```

### File Operations
- **Atomic Updates**: Configuration files updated atomically with backup creation
- **Thread Safety**: File operations protected with file_lock
- **Backup Strategy**: Automatic backup creation before each update
- **Directory Creation**: Automatic creation of missing directories

## Operational Metrics

### Statistics Tracking
```python
stats = {
    'total_wallets': 0,           # Total wallets processed in current sync
    'synced_wallets': 0,          # Successfully synchronized wallets
    'corrupted_wallets': 0,       # Wallets with missing required data
    'wallets_created': 0,         # New wallets generated for users
    'wallet_generation_errors': 0, # Failed wallet generation attempts
    'vaults_created': 0,          # BaitCoin vaults created
    'vaults_already_exist': 0,    # Existing vaults found
    'vault_creation_errors': 0,   # Failed vault creation attempts
    'flow_balance_checks': 0,     # FLOW balance queries executed
    'flow_funding_needed': 0,     # Wallets requiring funding
    'flow_funding_success': 0,    # Successful funding operations
    'flow_funding_errors': 0      # Failed funding operations
}
```

### Statistics Management
- **Thread Safety**: All statistics updates protected with stats_lock
- **Reset Functionality**: Statistics reset before each sync cycle
- **Real-time Updates**: Statistics updated during wallet processing
- **Summary Reporting**: Complete statistics printed after each sync

## Error Handling & Recovery

### Error Categories
- **Rate Limiting**: Automatic retry with exponential backoff
- **Network Errors**: Graceful degradation, continues with other wallets
- **Data Corruption**: Logs and skips corrupted wallet records
- **Blockchain State**: Attempts vault creation/capability publishing
- **File System Errors**: Handles permission, disk space, and locking issues
- **Database Errors**: Manages connection and query failures

### Recovery Mechanisms
- **Graceful Degradation**: Continues operation despite individual failures
- **Error Classification**: Distinguishes between different error types
- **Retry Logic**: Exponential backoff for transient failures
- **Comprehensive Logging**: Detailed error tracking with context
- **Skip and Continue**: Skips problematic wallets and continues processing
- **Service Continuity**: Maintains service operation during partial failures

### Error Handling Patterns
```python
# Database Error Pattern
try:
    result = database_operation()
except DatabaseError as e:
    log_error(f"Database error: {e}")
    if is_retryable(e):
        retry_with_backoff()
    else:
        skip_operation()

# Blockchain Error Pattern
try:
    result = blockchain_operation()
except BlockchainError as e:
    log_error(f"Blockchain error: {e}")
    if is_rate_limit(e):
        wait_and_retry()
    else:
        skip_wallet()

# File System Error Pattern
try:
    result = file_operation()
except FileSystemError as e:
    log_error(f"File system error: {e}")
    if is_critical(e):
        exit_service()
    else:
        continue_operation()
```

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

### Service Loop Details
```python
while self.running:
    if self.shutdown_event.wait(timeout=SYNC_INTERVAL):
        break  # Shutdown requested
    
    if not self.running:
        break  # Running flag cleared
    
    self._reset_stats()  # Reset statistics for new cycle
    if not self.sync_wallets():
        print("❌ Sync failed, will retry on next interval")
```

### Signal Handling
- **SIGTERM**: Graceful shutdown request from system
- **SIGINT**: Interrupt signal (Ctrl+C)
- **Response**: Sets running=False and shutdown_event
- **Cleanup**: Allows current operations to complete before exit

## Cadence Scripts & Transactions

### Scripts Used
- `checkFlowBalance.cdc`: Queries FLOW token balance for given address
- `checkBaitBalance.cdc`: Queries BaitCoin balance and vault status

### Transactions Used
- `fundWallet.cdc`: Funds wallets with FLOW tokens from service account
- `createAllVault.cdc`: Creates BaitCoin vaults for user accounts
- `publishBaitBalance.cdc`: Publishes balance capabilities for external access

### Script Execution Details
```python
# Flow Balance Check
result = self.flow_adapter.execute_script(
    script_path="cadence/scripts/checkFlowBalance.cdc",
    args=[address],
    network="mainnet"
)

# BaitCoin Balance Check
result = self.flow_adapter.execute_script(
    script_path="cadence/scripts/checkBaitBalance.cdc",
    args=[address],
    network="mainnet"
)
```

### Transaction Execution Details
```python
# Fund Wallet Transaction
result = self.flow_adapter.send_transaction(
    transaction_path="cadence/transactions/fundWallet.cdc",
    args=[address, str(amount)],
    proposer_wallet_id=funder_account,
    payer_wallet_id=funder_account,
    authorizer_wallet_ids=[funder_account],
    network="mainnet"
)

# Create Vault Transaction
result = self.flow_adapter.send_transaction(
    transaction_path="cadence/transactions/createAllVault.cdc",
    args=[f'0x{flow_address}'],
    proposer_wallet_id=auth_id,
    payer_wallet_id=payer_account,
    authorizer_wallet_ids=[auth_id],
    network="mainnet"
)
```

## Performance Optimization

### Scalability Features
- **Thread Pool Processing**: Up to 3 concurrent wallet processing threads
- **Database Optimization**: Paginated queries (1000 records per page)
- **Network Optimization**: Rate-limited API usage patterns
- **Resource Management**: Memory and CPU optimization with thread-safe operations

### Monitoring Capabilities
- **Real-time Metrics**: Live synchronization status with detailed statistics
- **Historical Trends**: Performance tracking across sync cycles
- **Error Analytics**: Detailed error categorization and logging
- **Resource Utilization**: Database and network usage monitoring

### Performance Characteristics
- **Rate Limiting**: 5 RPS for scripts, 50 RPS for transactions
- **Concurrent Processing**: Up to 3 wallets processed simultaneously
- **Memory Efficiency**: Streaming data processing with pagination
- **Error Resilience**: Continues operation despite individual failures

## Security Considerations

### Access Control
- **Service Role Authentication**: Elevated database privileges for Supabase operations
- **Private Key Management**: Secure file system storage in pkeys directory
- **Network Security**: Encrypted communication with Flow network
- **Audit Logging**: Comprehensive operation tracking with detailed logs

### Data Protection
- **Sensitive Data Handling**: Secure storage of private keys in isolated files
- **Transmission Security**: Encrypted API communications with Supabase and Flow
- **Access Logging**: Detailed audit trails for all operations
- **Backup Procedures**: Automatic configuration backups before updates

### Security Features
- **File Permissions**: Private key files stored with restricted permissions
- **Environment Variables**: Sensitive configuration via environment variables
- **Service Account Isolation**: Single service account for funding operations
- **Error Sanitization**: Sensitive data excluded from error logs

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

### Environment Setup
```bash
# Required environment variables
export SUPABASE_URL="your_supabase_url"
export SUPABASE_SERVICE_ROLE_KEY="your_service_role_key"
export SYNC_INTERVAL="300"  # Optional, defaults to 300 seconds
```

### Docker Usage
```bash
# Build and run with Docker
docker build -t wallet-sync-service .
docker run -d --name wallet-sync \
  -e SUPABASE_URL="your_url" \
  -e SUPABASE_SERVICE_ROLE_KEY="your_key" \
  -v $(pwd)/flow:/app/flow \
  wallet-sync-service
```

## Key Features

- **Real-time Synchronization**: Continuous wallet state management with configurable intervals
- **Automated Funding**: Ensures sufficient FLOW balance for operations (0.075 FLOW threshold)
- **Vault Management**: Creates and manages BaitCoin vaults with capability publishing
- **Rate Limiting**: Compliant with Flow network constraints (5 RPS scripts, 50 RPS transactions)
- **Error Recovery**: Robust error handling and recovery mechanisms with graceful degradation
- **Multi-threading**: Efficient processing with thread-safe operations (up to 3 concurrent threads)
- **Configuration Management**: Dynamic Flow CLI configuration generation with atomic updates
- **Monitoring**: Comprehensive operational metrics and statistics with real-time reporting
- **Security**: Secure private key management with service role authentication
- **Scalability**: Paginated data processing and concurrent wallet operations

## Troubleshooting

### Common Issues
1. **Missing Environment Variables**: Ensure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set
2. **Flow Directory Not Found**: Verify flow directory exists and is accessible
3. **Database Connection Issues**: Check Supabase credentials and network connectivity
4. **Rate Limiting Errors**: Service automatically handles rate limits with backoff
5. **Private Key File Errors**: Ensure pkeys directory exists and is writable

### Debug Mode
```bash
# Run with verbose logging
PYTHONPATH=. python3 -u syncWalletsService.py
```

### Log Analysis
- **Success Indicators**: "✓" symbols indicate successful operations
- **Error Indicators**: "❌" symbols indicate failed operations
- **Warning Indicators**: "⚠️" symbols indicate warnings or issues
- **Debug Information**: "🔍" symbols indicate debug information

---

*This service provides the critical infrastructure for maintaining consistency between the DerbyFish ecosystem's database and Flow blockchain network, ensuring reliable wallet management and blockchain operations with enterprise-grade reliability and security.*