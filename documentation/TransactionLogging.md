# Transaction Logging with FlowWrapper

This document describes how to use the new transaction logging functionality integrated into the FlowWrapper.

## Overview

The FlowWrapper now includes comprehensive transaction logging that tracks all Flow blockchain operations in a Supabase database. This provides:

- Complete transaction history
- Status tracking (pending, submitted, sealed, executed, failed, expired)
- Detailed logging with timestamps
- Wallet relationship tracking
- Performance metrics (execution time, gas usage)
- Error tracking and debugging information

## Database Schema

The `transactions` table includes the following key fields:

- `flow_transaction_id`: Flow blockchain transaction ID
- `transaction_type`: Type of operation (script, transaction, mint, burn, transfer, swap)
- `status`: Current status of the transaction
- `proposer_wallet_id`: Wallet that initiated the transaction
- `payer_wallet_id`: Wallet that pays for the transaction
- `authorizer_wallet_ids`: Array of wallets that authorized the transaction
- `logs`: JSON array of detailed logs with timestamps
- `result_data`: Transaction results and data
- `execution_time_ms`: Performance metrics
- `error_message`: Error details if transaction failed

## Usage Examples

### Basic Script Execution with Logging

```typescript
import { createFlowWrapper } from './src/typescript/flowWrapper';

const flowWrapper = createFlowWrapper('mainnet');

// Execute a script with wallet tracking
const result = await flowWrapper.executeScript(
    'cadence/scripts/totalMintedBait.cdc',
    ['0x1234567890abcdef'],
    'wallet-uuid-here' // proposer wallet ID
);

console.log('Script result:', result.data);
console.log('Database transaction ID:', result.transactionId);
```

### Transaction Execution with Full Wallet Tracking

```typescript
// Send a transaction with comprehensive wallet tracking
const result = await flowWrapper.sendTransaction(
    'cadence/transactions/sendBait.cdc',
    ['0x1234567890abcdef', '100.0'], // arguments
    {
        proposer: 'user-wallet',
        payer: 'service-account',
        authorizer: ['user-wallet']
    },
    {}, // private keys
    'proposer-wallet-uuid', // proposer wallet ID
    'payer-wallet-uuid',    // payer wallet ID
    ['authorizer-wallet-uuid'] // authorizer wallet IDs
);

console.log('Flow transaction ID:', result.transactionId);
console.log('Database transaction ID:', result.dbTransactionId);
```

### Transaction History and Management

```typescript
// Get transaction history for a wallet
const history = await flowWrapper.getTransactionHistory('wallet-uuid-here', 20);

// Get specific transaction by database ID
const transaction = await flowWrapper.getTransactionById('transaction-uuid-here');

// Get transaction by Flow blockchain ID
const flowTransaction = await flowWrapper.getTransactionByFlowId('0x1234567890abcdef');

// Add custom log entry to a transaction
await flowWrapper.addTransactionLog('transaction-uuid-here', {
    level: 'info',
    message: 'Custom processing step completed',
    data: { step: 'validation', result: 'success' }
});

// Update transaction status
await flowWrapper.updateTransactionStatus('transaction-uuid-here', 'executed', {
    notes: 'Transaction completed successfully'
});
```

## Environment Configuration

Make sure to set up the following environment variables:

```bash
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
SUPABASE_JWT_SECRET=your_supabase_jwt_secret
```

## Migration

Run the migration to create the transactions table:

```sql
-- Run the migration file
\i migrations/003_create_transactions_table.sql
```

## Transaction Status Flow

1. **pending**: Transaction created, not yet submitted
2. **submitted**: Transaction submitted to Flow network
3. **sealed**: Transaction sealed on Flow blockchain
4. **executed**: Transaction executed successfully (for scripts)
5. **failed**: Transaction failed with error
6. **expired**: Transaction expired without being sealed

## Logging Structure

Each transaction includes detailed logs with the following structure:

```json
{
  "level": "info|error|warning",
  "message": "Human readable message",
  "timestamp": "2025-01-20T10:30:00.000Z",
  "execution_time_ms": 1500,
  "data": { /* additional context data */ }
}
```

## Security

- Row Level Security (RLS) is enabled on the transactions table
- Users can only access transactions where they are the proposer, payer, or authorizer
- Service role key is used for server-side operations
- Private keys are never logged or stored in the database

## Performance Considerations

- Transaction logging is asynchronous and won't block Flow operations
- Logs are stored as JSONB for efficient querying
- Indexes are created on commonly queried fields
- Consider archiving old transactions for better performance
