#!/bin/bash

# Startup script for Flow Wallet Sync Service
# This script ensures the necessary directories and files exist before starting the sync service

set -e

echo "🚀 Starting Flow Wallet Sync Service Setup..."

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p /home/mattricks/pkeys
mkdir -p /home/mattricks/flow-accounts

# Create initial flow-production.json if it doesn't exist
if [ ! -f "/home/mattricks/flow-production.json" ]; then
    echo "📄 Creating initial flow-production.json..."
    echo '{"accounts": {}}' > /home/mattricks/flow-production.json
fi

# Ensure proper permissions
echo "🔐 Setting proper permissions..."
chmod 755 /home/mattricks/pkeys
chmod 644 /home/mattricks/flow-production.json

# Check if mainnet-agfarms.pkey exists
if [ ! -f "/home/mattricks/mainnet-agfarms.pkey" ]; then
    echo "⚠️  Warning: mainnet-agfarms.pkey not found at /home/mattricks/mainnet-agfarms.pkey"
    echo "   Please ensure this file exists for the sync service to work properly"
fi

echo "✅ Setup complete! Starting Docker Compose..."

# Start the services
docker-compose up -d

echo "🎉 Flow Wallet Sync Service started!"
echo "📊 Monitor logs with: docker-compose logs -f derbyfish-flow-sync"
echo "🔍 Check API logs with: docker-compose logs -f derbyfish-flow-api"
