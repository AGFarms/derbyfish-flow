# Flow Python Adapter

A production-ready Python adapter for Flow blockchain operations using flow-py-sdk with comprehensive error handling.

## Architecture Overview

The FlowPyAdapter implements a two-layer architecture for executing Flow blockchain transactions through HTTP endpoints:

1. **HTTP Layer** (`app.py`) - Flask REST API with JWT/admin authentication
2. **Adapter Layer** (`flow_py_adapter.py`) - Python Flow SDK integration using flow-py-sdk
3. **Blockchain Layer** - Flow network execution via gRPC access nodes

### Authentication System

**User Authentication (`@require_auth`)**:
- JWT verification using Supabase tokens with HS256 algorithm
- Wallet resolution from database using user ID (`sub` claim)
- Context injection: `request.user_payload` and `request.wallet_details`

**Admin Authentication (`@require_admin_auth`)**:
- Secret key verification via string comparison with `ADMIN_SECRET_KEY`
- Bearer token format: `Authorization: Bearer <admin_secret>`

## Transaction Execution Flows

### Send BAIT Transaction

**HTTP Request**:
```http
POST /transactions/send-bait
Authorization: Bearer <supabase_jwt>
Content-Type: application/json
{"to_address": "0x1234567890abcdef", "amount": "100.0"}
```

**Execution Pipeline**:
1. **Authentication**: JWT verification → wallet lookup → user context injection
2. **Role Configuration**: `{proposer: user_id, authorizer: [user_id], payer: 'mainnet-agfarms'}`
3. **Adapter Layer**: Python subprocess call to TypeScript CLI with base64-encoded payload
4. **FCL Execution**: `fcl.mutate()` with user authorization for proposer/authorizer, service authorization for payer
5. **Cadence Transaction**: `sendBait.cdc` - withdraws from sender's vault, deposits to recipient's receiver capability

**Cadence Implementation**:
```cadence
transaction(to: Address, amount: UFix64) {
    prepare(sender: auth(BorrowValue, Storage) &Account) {
        let senderVault = sender.storage.borrow<auth(FungibleToken.Withdraw) &BaitCoin.Vault>(from: /storage/baitCoinVault)
        let recipient = getAccount(to)
        let recipientReceiver = recipient.capabilities.get<&{FungibleToken.Receiver}>(/public/baitCoinReceiver)
        let baitVault <- senderVault.withdraw(amount: amount)
        recipientReceiver.deposit(from: <-baitVault)
    }
}
```

### Admin Mint BAIT Transaction

**HTTP Request**:
```http
POST /transactions/admin-mint-bait
Authorization: Bearer <admin_secret>
Content-Type: application/json
{"to_address": "0x1234567890abcdef", "amount": "1000.0"}
```

**Execution Pipeline**:
1. **Admin Authentication**: Secret key verification
2. **Role Configuration**: `{proposer: 'mainnet-agfarms', authorizer: 'mainnet-agfarms', payer: 'mainnet-agfarms'}`
3. **Same adapter/FCL layers** as send_bait
4. **Admin Cadence Transaction**: `adminMintBait.cdc` - uses admin resource to mint new tokens

**Cadence Implementation**:
```cadence
transaction(to: Address, amount: UFix64) {
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        let adminResource = signer.storage.borrow<&BaitCoin.Admin>(from: /storage/baitCoinAdmin)
        let recipientAccount = getAccount(to)
        let recipientReceiver = recipientAccount.capabilities.get<&{FungibleToken.Receiver}>(/public/baitCoinReceiver)
        adminResource.mintBait(amount: amount, recipient: to)
    }
}
```

## Account Management & Authorization

### Service Account (`mainnet-agfarms`)
- **Purpose**: Transaction fee payment, fallback authorization
- **Configuration**: `flow/mainnet-agfarms.pkey` + `flow.json` account definition
- **Usage**: Always payer for user transactions, full authorization for admin operations

### User Accounts
- **Identification**: JWT `sub` claim maps to Flow account name
- **Configuration**: `flow/accounts/flow-production.json` + `flow/accounts/pkeys/{user_id}.pkey`
- **Authorization**: User must explicitly authorize their own transactions

### Admin Account
- **Resource**: Admin resource stored in `/storage/baitCoinAdmin`
- **Access Control**: Only accounts with admin resource can perform mint/burn operations
- **Security**: Admin secret must be protected, all admin operations logged

## Technical Implementation

### TypeScript FCL Integration
```typescript
// flowWrapper.ts - Authorization factory
authzFactory(address: string, keyId: number, privateKey: string, signatureAlgorithm: string, hashAlgorithm: string) {
    const ec = new EC(signatureAlgorithm === 'ECDSA_secp256k1' ? 'secp256k1' : 'p256');
    const key = ec.keyFromPrivate(Buffer.from(privateKey, 'hex'));
    
    return async function authz(account: any) {
        return {
            ...account,
            tempId: `${address}-${keyId}`,
            addr: fcl.sansPrefix(address),
            keyId: Number(keyId),
            signingFunction: async function(signable: any) {
                const message = Buffer.from(signable.message, 'hex');
                const digest = hashAlgorithm === 'SHA3_256' 
                    ? nodeCrypto.createHash('sha3-256').update(message).digest()
                    : nodeCrypto.createHash('sha256').update(message).digest();
                const signature = key.sign(digest);
                return { addr: fcl.withPrefix(address), keyId: Number(keyId), signature: sigHex };
            }
        };
    };
}
```

### Python Adapter
```python
# flow_py_adapter.py - flow-py-sdk integration
async def _execute_script_async(self, script_path: str, args: List[Any], network: str) -> Dict[str, Any]:
    async with flow_client(host=host, port=port) as client:
        result = await client.execute_script(script=script)
    return {'success': True, 'data': result, ...}
```

## Security & Error Handling

### Authentication Security
- **JWT Validation**: Signature verification, expiration checking, algorithm validation
- **Admin Secret**: Environment variable protection, bearer token format enforcement
- **Wallet Resolution**: Database lookup with service role key bypassing RLS

### Transaction Security
- **Authorization Patterns**: User transactions require explicit user authorization, admin transactions use admin-only authorization
- **Fee Payment**: Service account pays fees to prevent user transaction failures
- **Balance Validation**: Cadence enforces sufficient balance before token withdrawal

### Error Categories & Retry Logic
- **Rate Limiting**: Automatic retry with exponential backoff (scripts: 200ms, transactions: 20ms)
- **Network Errors**: Timeout handling with configurable limits (default: 300s)
- **Validation Errors**: Non-retryable (insufficient funds, missing vaults, invalid parameters)
- **Authentication Errors**: Non-retryable (invalid tokens, missing permissions)

## Performance & Monitoring

### Metrics Collection
- **Operation Tracking**: Success rates, execution times, retry counts per operation type
- **Network Monitoring**: Breakdown by network (mainnet/testnet/emulator)
- **Rate Limiting**: Track rate-limited operations and timeout occurrences

### Thread Safety
- **Concurrent Execution**: Thread-safe rate limiting and metrics collection
- **Multiple Instances**: Support for multiple wrapper instances in parallel
- **Background Processing**: Thread-based background task execution with result storage

## Key Differences: Send vs Admin Mint

| Aspect | Send BAIT | Admin Mint BAIT |
|--------|-----------|-----------------|
| **Authentication** | JWT (user) | Admin Secret |
| **Authorization** | User + Service | Admin Only |
| **Transaction Type** | Transfer existing tokens | Create new tokens |
| **Prerequisites** | User must have BAIT tokens | Recipient must have vault |
| **Permission Level** | User operation | Admin operation |
| **Fee Payment** | Service account | Admin account |

