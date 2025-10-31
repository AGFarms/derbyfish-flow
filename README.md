# DerbyFish Flow API

**Public-facing REST API infrastructure for minting verified Fish Cards on the Flow blockchain**

---

## 🎯 Vision

**A Universal API for Verified Catch Infrastructure**

DerbyFish Flow API is a **public-facing, production-ready HTTP API** that enables any application, service, or private agent to mint verified Fish Cards through our standardized verification pipeline. We're building the infrastructure layer that transforms fishing verification from fragmented, one-off implementations into a unified, interoperable standard.

### The Big Picture

**Today:** Any developer, application, or automated system can integrate Fish Card minting via simple HTTP requests. Our API handles authentication, verification workflows, Flow blockchain interactions, and NFT creation—all behind a clean REST interface.

**Tomorrow:** We envision a decentralized ecosystem where:
- **Any wallet** can integrate Fish Card verification directly
- **Any scanning tool** (mobile apps, IoT devices, GoPros, underwater cameras) can submit verified catches
- **Any tournament platform** can leverage our verification infrastructure instead of rebuilding it
- **Any AI agent** can process catches and mint cards programmatically

### Why This Matters

The fishing industry is fragmented. Tournament apps, fishing platforms, and verification tools all rebuild the same infrastructure in isolation. DerbyFish Flow API provides the **base layer** that others can build on—standardizing proof-of-catch, reducing fraud, and creating permanent digital records that persist across platforms and time.

### FishCard: Abstract by Design

Our [FishCardV1 contract](./flow/cadence/contracts/FishCardV1.cdc) is deliberately abstract and extensible. It supports multiple verification standards (BHRV, FishScan, BanannaScan) and is designed to accommodate future verification methods, media types, and use cases we haven't imagined yet. The contract provides:

- **Flexible verification pipelines** - Plug in any verification method
- **Extensible media storage** - Support any capture device or format  
- **Rich metadata** - Public and private data layers for different use cases
- **Marketplace compatibility** - Standard NFT interfaces for trading
- **Decentralized storage** - Flow's infrastructure ensures permanence

**The vision is simple:** We provide the verification infrastructure. You build the experiences.

---

## 🚀 Quick Start

### Installation

1. **Install Python dependencies:**
```bash
pip install -r requirements.txt
```

2. **Configure environment variables:**
```bash
cp env.example .env
# Edit .env with your Supabase and Flow configuration
```

3. **Start the API server:**
```bash
python src/python/app.py
```

The server will start on `http://localhost:5000`

### Your First Fish Card

Check the balance endpoint to verify your wallet connection:

```bash
curl -X GET "http://localhost:5000/scripts/check-bait-balance?address=0x179b6b1cb6755e31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 📚 API Documentation

### Authentication

Most endpoints require JWT authentication via Supabase. Include your token in the `Authorization` header:

```
Authorization: Bearer YOUR_SUPABASE_JWT_TOKEN
```

For admin operations, use the admin secret key:

```
Authorization: Bearer YOUR_ADMIN_SECRET_KEY
```

### Core Endpoints

#### Scripts (Read Operations)

- `GET /scripts/check-bait-balance?address=<address>` - Check BAIT token balance
- `GET /scripts/check-contract-vaults` - Check contract vaults

#### Transactions (Write Operations)

**User Operations:**
- `POST /transactions/send-bait` - Send BAIT tokens to another address
- `POST /transactions/swap-bait-for-fusd` - Swap BAIT for FUSD
- `POST /transactions/swap-fusd-for-bait` - Swap FUSD for BAIT

**Admin Operations:**
- `POST /transactions/admin-mint-bait` - Mint BAIT tokens (requires admin auth)
- `POST /transactions/admin-burn-bait` - Burn BAIT tokens (requires admin auth)
- `POST /transactions/admin-mint-fusd` - Mint FUSD tokens (requires admin auth)

#### Background Tasks

- `POST /background/run-script` - Execute scripts asynchronously
- `POST /background/run-transaction` - Execute transactions asynchronously
- `GET /background/task/<task_id>` - Check task status
- `GET /background/tasks` - List all tasks

#### Utility

- `GET /` - API documentation
- `GET /health` - Health check
- `GET /auth/test` - Test JWT authentication
- `GET /auth/status` - Check authentication configuration

---

## 💡 Integration Examples

### Example 1: Send BAIT Tokens

```bash
curl -X POST "http://localhost:5000/transactions/send-bait" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "to_address": "0x44100f14f70e3f78",
    "amount": "100.0",
    "network": "mainnet"
  }'
```

### Example 2: Check Balance with User's Wallet

```bash
curl -X GET "http://localhost:5000/scripts/check-bait-balance" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

If no address is provided, the API automatically uses the authenticated user's wallet address.

### Example 3: Admin Mint BAIT Tokens

```bash
curl -X POST "http://localhost:5000/transactions/admin-mint-bait" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ADMIN_SECRET" \
  -d '{
    "to_address": "0x179b6b1cb6755e31",
    "amount": "1000.0",
    "network": "mainnet"
  }'
```

### Example 4: Background Script Execution

```bash
curl -X POST "http://localhost:5000/background/run-script" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "script_name": "checkBaitBalance.cdc",
    "args": ["0x179b6b1cb6755e31"],
    "network": "mainnet"
  }'
```

Then check the task status:

```bash
curl -X GET "http://localhost:5000/background/task/<task_id>" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 🔧 Configuration

### Network Support

The API supports multiple Flow networks:
- `mainnet` (default) - Production Flow network
- `testnet` - Flow test network
- `emulator` - Local Flow emulator

Specify the network in request parameters or use the default mainnet.

### Environment Variables

Required environment variables (see `env.example`):
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_ANON_KEY` - Supabase anonymous key
- `SUPABASE_SERVICE_ROLE_KEY` - Supabase service role key (for server-side operations)
- `SUPABASE_JWT_SECRET` - JWT secret for token verification
- `ADMIN_SECRET_KEY` - Admin secret for admin operations

---

## 📖 Response Format

All endpoints return JSON responses with consistent structure:

### Success Response
```json
{
  "success": true,
  "stdout": "Command output",
  "data": {...},
  "transaction_id": "abc123...",
  "execution_time": 1.23,
  "returncode": 0
}
```

### Error Response
```json
{
  "success": false,
  "error": "Error message",
  "stdout": "...",
  "stderr": "...",
  "returncode": 1
}
```

### Background Task Response
```json
{
  "status": "completed",
  "start_time": "2025-01-01T12:00:00",
  "end_time": "2025-01-01T12:00:01",
  "duration": 1.0,
  "result": {...}
}
```

---

## 🏗️ Architecture

### Components

- **Flask API Server** (`src/python/app.py`) - Main HTTP server
- **Flow Node Adapter** (`src/python/flow_node_adapter.py`) - Flow blockchain integration
- **Supabase Integration** - User authentication and wallet management
- **FishCardV1 Contract** (`flow/cadence/contracts/FishCardV1.cdc`) - NFT contract on Flow

### Flow Integration

The API uses Flow's JavaScript SDK (via Node.js) to interact with the blockchain:
- Script execution for read operations
- Transaction signing and submission for write operations
- Multi-role transaction support (proposer, authorizer, payer)
- Private key management for custodial wallets

### Wallet Management

The API supports both:
- **User wallets** - Authenticated via Supabase JWT, stored in database
- **Admin wallets** - System wallets for administrative operations

All wallet operations are custodialized—users never manage private keys directly.

---

## 🔒 Security

### Authentication

- **JWT Authentication** - All user endpoints require valid Supabase JWT tokens
- **Admin Secret** - Admin endpoints require a separate secret key
- **RLS Policies** - Database-level security via Supabase Row Level Security

### Best Practices

- Store admin secrets securely (never commit to version control)
- Use HTTPS in production
- Implement rate limiting for production deployments
- Validate all input parameters
- Monitor transaction status and handle failures gracefully

---

## 🚧 Development

### Running Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Start development server
python src/python/app.py
```

The server runs in debug mode by default on `http://0.0.0.0:5000`

### Production Considerations

- Set `debug=False` in Flask app
- Use a production WSGI server (Gunicorn, uWSGI)
- Implement proper logging
- Add rate limiting and request validation
- Set up monitoring and alerting
- Use environment-specific configuration

---

## 📝 FishCard Contract

The [FishCardV1 contract](./flow/cadence/contracts/FishCardV1.cdc) implements Flow's standard NFT interfaces with specialized features for fishing verification:

- **Multiple verification standards** - BHRV, FishScan, BanannaScan
- **Decentralized media storage** - Flow storage with stake requirements
- **Public/private metadata** - Different data visibility levels
- **Marketplace compatibility** - Standard MetadataViews implementation
- **Extensible design** - Ready for future verification methods

See [FishCardV1.md](./documentation/FishCardV1.md) for complete contract documentation.

---

## 🤝 Contributing

This API is part of the DerbyFish ecosystem. For integration questions or feature requests, contact:

- **Team**: team@agfarms
- **Phone**: +1 (562) 576-3892
- **CEO**: mattrickslauer@gmail.com

---

## 📄 License

This project is part of the DerbyFish Flow infrastructure.

---

## 🔗 Resources

- [Flow Blockchain](https://flow.com/)
- [Flow Documentation](https://docs.onflow.org/)
- [DerbyFish](https://derby.fish/)
- [FishCardV1 Documentation](./documentation/FishCardV1.md)
