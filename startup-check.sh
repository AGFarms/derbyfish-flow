#!/bin/bash

echo "=== DOCKER CONTAINER STARTUP CHECK ==="
echo "Checking Flow configuration and private key files..."

# Check if flow directory exists
if [ -d "/app/flow" ]; then
    echo "✓ Flow directory exists: /app/flow"
else
    echo "✗ Flow directory missing: /app/flow"
    exit 1
fi

# Check if flow.json exists
if [ -f "/app/flow/flow.json" ]; then
    echo "✓ flow.json exists"
    echo "Accounts in flow.json:"
    cat /app/flow/flow.json | jq -r '.accounts | keys[]' 2>/dev/null || echo "Could not parse flow.json"
else
    echo "✗ flow.json missing"
fi

# Check if mainnet-agfarms.pkey exists
if [ -f "/app/flow/mainnet-agfarms.pkey" ]; then
    echo "✓ mainnet-agfarms.pkey exists"
    echo "Private key file size: $(wc -c < /app/flow/mainnet-agfarms.pkey) bytes"
    echo "Private key preview: $(head -c 8 /app/flow/mainnet-agfarms.pkey)...$(tail -c 8 /app/flow/mainnet-agfarms.pkey)"
else
    echo "✗ mainnet-agfarms.pkey missing"
fi

# Check if flow-production.json exists
if [ -f "/app/flow/accounts/flow-production.json" ]; then
    echo "✓ flow-production.json exists"
    echo "Accounts in flow-production.json:"
    cat /app/flow/accounts/flow-production.json | jq -r '.accounts | keys[]' 2>/dev/null | head -10 || echo "Could not parse flow-production.json"
else
    echo "✗ flow-production.json missing"
fi

# Check Node.js version
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Check if TypeScript CLI is built
if [ -f "/app/dist/cli.js" ]; then
    echo "✓ TypeScript CLI built successfully"
else
    echo "✗ TypeScript CLI not found"
fi

echo "=== STARTUP CHECK COMPLETE ==="
echo ""
