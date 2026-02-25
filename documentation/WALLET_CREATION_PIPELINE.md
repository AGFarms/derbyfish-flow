# Wallet Creation Pipeline

Automated Flow wallet creation triggered by user signup. Private keys are salted and encrypted in the database.

## Architecture

1. **User signup** → `auth.users` INSERT
2. **handle_new_user** trigger → INSERT `wallet` (auth_id, NULL, NULL, NULL)
3. **Supabase Database Webhook** → POST to `/internal/create-wallet`
4. **Flask** → create_account (flow-py-sdk) → encrypt key → UPDATE wallet, write pkey file, update flow-production.json

## Security

- **Private keys**: AES-256-GCM encrypted with per-row salt (PBKDF2 key derivation)
- **Storage**: Encrypted blob in `wallet.flow_private_key`; salt embedded in blob
- **Decryption**: Only at signing time; never logged or exposed

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `WALLET_ENCRYPTION_KEY` | Yes (for create-wallet) | 32-byte hex (64 chars) or 44-char base64. Used to encrypt/decrypt private keys. |
| `WEBHOOK_SECRET` | Yes (for webhook) | Bearer token for `/internal/create-wallet`. Falls back to `ADMIN_SECRET_KEY` if unset. |
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Service role key (bypasses RLS) |

## Supabase Database Webhook

1. Dashboard → Database → Webhooks → Create
2. **Name**: `wallet_create_trigger`
3. **Table**: `public.wallet`
4. **Events**: Insert
5. **URL**: `https://<flask-host>/internal/create-wallet`
6. **HTTP method**: POST
7. **Headers**:
   - `Authorization`: `Bearer <WEBHOOK_SECRET>`
   - `Content-Type`: `application/json`

Payload format (Supabase sends):
```json
{
  "type": "INSERT",
  "table": "wallet",
  "record": { "id": "...", "auth_id": "...", "flow_address": null, ... }
}
```

## Migration

Run `migrations/005_wallet_creation_pipeline.sql` to:
- Add wallet INSERT to `handle_new_user`

## Legacy Wallets

Wallets created before encryption use plaintext `flow_private_key`. The app detects format: 64-char hex = plaintext, else encrypted. Migrate legacy keys by re-creating or running an encryption migration.
