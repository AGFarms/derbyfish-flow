# DerbyFish Testing Functions Guide

This document provides comprehensive testing commands for all parts of the DerbyFish ecosystem on Flow testnet.

---

## 🎣 NFT Testing

### Get Specific NFT by ID
```bash
# Get detailed information about a specific Fish NFT
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc <test-addr> <nft_id> --network testnet

# Example:
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc <test-addr> 1 --network testnet
```

**Returns:** Complete NFT metadata including:
- Core catch data (species, length, weight, timestamp)
- Location data (coordinates, water body)
- Media (bump shot, hero shot, release video)
- Verification status
- Species code for coin minting
- Private data (if caller is owner)

### Get All NFT IDs for Account
```bash
# List all Fish NFT IDs owned by an account
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc <test-addr> --network testnet
```

---

## 🪙 WalleyeCoin Testing

### Basic Balance Check
```bash
# Get WalleyeCoin balance for an account
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc <test-addr> --network testnet
```

### Comprehensive WalleyeCoin Information
```bash
# Get detailed WalleyeCoin contract metadata and account info
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc <test-addr> --network testnet
```

**Returns:** 
- Vault setup status
- Balance information
- Public capability status
- Interface compliance
- Contract metadata
- Species information

### Complete WalleyeCoin Metadata Profile
```bash
# Get ALL WalleyeCoin metadata - comprehensive species data dump
flow scripts execute cadence/scripts/get_walleye_coin_all_metadata.cdc --network testnet
```

**Returns:** Complete species profile including:
- **Contract Overview** - Basic info, supply metrics, data quality scores
- **Species Profile** - Conservation status, biological data, angling info, world records
- **Regional Data** - Population data for Great Lakes, Canadian Shield, Mississippi River System
- **Economic Data** - Commercial values by region, tourism ratings, ecosystem role
- **Physical Traits** - Size, behavior, seasonal patterns, physical description
- **Habitat Data** - Native regions, water types, temperature/depth preferences
- **Reproduction Data** - Spawning behavior, migration patterns, lifespan
- **Research Data** - Study programs, genetic markers, research priority
- **Community Data** - Pending updates, additional metadata
- **FishDEX Integration** - Registration status, contract addresses

### Species Coin Balance (Generic)
```bash
# Get balance for any species coin by ticker
flow scripts execute cadence/scripts/get_species_coin_balance.cdc <test-addr> <ticker> --network testnet

# Examples:
flow scripts execute cadence/scripts/get_species_coin_balance.cdc <test-addr> "SANVIT" --network testnet
flow scripts execute cadence/scripts/get_species_coin_balance.cdc <test-addr> "EXFISH" --network testnet
```

---

## 🐟 Species Registry Testing

### Check Registered Species
```bash
# Get all registered species in the system
flow scripts execute cadence/scripts/get_registered_species.cdc --network testnet
```

**Returns:** Complete list of species codes and their contract addresses

---

## 💰 BaitCoin & FUSD Testing

### BaitCoin Balance
```bash
# Get BaitCoin balance
flow scripts execute cadence/scripts/get_bc_balance.cdc <test-addr> --network testnet
```

### FUSD Balance
```bash
# Get FUSD balance
flow scripts execute cadence/scripts/get_fusd_balance.cdc <test-addr> --network testnet
```

### Contract FUSD Balance
```bash
# Get FUSD balance held by a contract
flow scripts execute cadence/scripts/get_contract_fusd_balance.cdc --network testnet
```

---

## 🎴 FishCard Testing

### Get FishCard by ID
```bash
# Get detailed information about a specific FishCard
flow scripts execute cadence/scripts/get_fish_card_by_id.cdc <test-addr> <card_id> --network testnet
```

### Get All FishCard IDs
```bash
# Get all FishCard IDs owned by an account
flow scripts execute cadence/scripts/get_fish_card_ids.cdc <test-addr> --network testnet
```

---

## 🔄 Transfer Testing

### Transfer FishCard
```bash
# Transfer a FishCard between accounts
flow transactions send cadence/transactions/transfer_fish_card.cdc <recipient-addr> <card_id> \
  --signer testnet-account \
  --network testnet
```

### Transfer BaitCoin
```bash
# Transfer BaitCoin between accounts
flow transactions send cadence/transactions/transfer_baitcoin.cdc <recipient-addr> <amount> \
  --signer testnet-account \
  --network testnet
```

---

## 🏗️ Account Setup Testing

### Setup Fish NFT Collection
```bash
# Set up Fish NFT collection for an account
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc \
  --signer <account> \
  --network testnet

# Verify setup
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc <account> --network testnet
```

### Setup WalleyeCoin Vault
```bash
# Set up WalleyeCoin vault for an account
flow transactions send cadence/transactions/setup_walleye_coin_account.cdc \
  --signer <account> \
  --network testnet

# Verify setup
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc <account> --network testnet
```

### Setup Species Coin Vault (Generic)
```bash
# Set up vault for any species coin
flow transactions send cadence/transactions/setup_species_coin_account.cdc \
  --signer <account> \
  --network testnet
```

### Setup BaitCoin Account
```bash
# Set up BaitCoin vault
flow transactions send cadence/transactions/setup_bc_account.cdc \
  --signer <account> \
  --network testnet
```

### Setup FUSD Account
```bash
# Set up FUSD vault
flow transactions send cadence/transactions/setup_fusd_account.cdc \
  --signer <account> \
  --network testnet
```

---

## 🧪 Advanced Testing Scenarios

### Test Complete Catch Flow
```bash
# 1. Set up NFT collection
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --signer testnet-account --network testnet

# 2. Set up WalleyeCoin vault
flow transactions send cadence/transactions/setup_walleye_coin_account.cdc --signer testnet-account --network testnet

# 3. Register species (if needed)
flow transactions send cadence/transactions/register_species.cdc \
  --args-json '[
    {"type": "String", "value": "SANDER_VITREUS"},
    {"type": "Address", "value": "<contract-addr>"}
  ]' \
  --signer testnet-account \
  --network testnet

# 4. Mint Fish NFT with comprehensive metadata
flow transactions send cadence/transactions/mint_fish_nft_with_species.cdc \
  --args-json '[
    {"type": "Address", "value": "<test-addr>"},
    {"type": "String", "value": "Walleye"},
    {"type": "String", "value": "Sander vitreus"},
    {"type": "UFix64", "value": "24.5"},
    {"type": "Optional", "value": {"type": "UFix64", "value": "3.2"}},
    {"type": "UFix64", "value": "1640995200.0"},
    {"type": "String", "value": "SANDER_VITREUS"},
    {"type": "Bool", "value": false},
    {"type": "String", "value": "https://example.com/bump.jpg"},
    {"type": "String", "value": "https://example.com/hero.jpg"},
    {"type": "String", "value": "abc123hash"},
    {"type": "String", "value": "def456hash"},
    {"type": "Optional", "value": null},
    {"type": "Optional", "value": null},
    {"type": "Fix64", "value": "-93.2650"},
    {"type": "Fix64", "value": "44.9778"},
    {"type": "Optional", "value": {"type": "String", "value": "Lake Minnetonka"}},
    {"type": "Optional", "value": {"type": "UFix64", "value": "45.0"}},
    {"type": "Optional", "value": {"type": "UFix64", "value": "72.0"}},
    {"type": "Optional", "value": {"type": "String", "value": "Partly Cloudy"}},
    {"type": "Optional", "value": {"type": "String", "value": "Waxing Gibbous"}},
    {"type": "Optional", "value": null},
    {"type": "Optional", "value": {"type": "UFix64", "value": "30.15"}},
    {"type": "Optional", "value": {"type": "UFix64", "value": "8.5"}},
    {"type": "Optional", "value": {"type": "String", "value": "NW"}},
    {"type": "Optional", "value": {"type": "String", "value": "Partly Cloudy"}},
    {"type": "Optional", "value": {"type": "UFix64", "value": "12.0"}},
    {"type": "Optional", "value": {"type": "String", "value": "Rocky Point"}},
    {"type": "Optional", "value": {"type": "String", "value": "Weed Bed"}},
    {"type": "Optional", "value": {"type": "String", "value": "North Shore"}},
    {"type": "Optional", "value": {"type": "String", "value": "Clear"}},
    {"type": "Optional", "value": {"type": "String", "value": "Moderate"}},
    {"type": "Optional", "value": {"type": "String", "value": "Jig and Minnow"}},
    {"type": "Optional", "value": {"type": "String", "value": "Fathead Minnow"}},
    {"type": "Optional", "value": {"type": "UFix64", "value": "180.0"}},
    {"type": "Optional", "value": {"type": "String", "value": "Vertical Jigging"}},
    {"type": "Optional", "value": {"type": "UFix64", "value": "16.5"}},
    {"type": "Optional", "value": {"type": "String", "value": "Medium Action"}},
    {"type": "Optional", "value": {"type": "String", "value": "Spinning"}},
    {"type": "Optional", "value": {"type": "String", "value": "8lb Mono"}},
    {"type": "Optional", "value": {"type": "String", "value": "6lb Fluoro"}},
    {"type": "Optional", "value": {"type": "String", "value": "#4 Jig Head"}},
    {"type": "Optional", "value": {"type": "String", "value": "Vertical"}},
    {"type": "Optional", "value": {"type": "String", "value": "Slow"}},
    {"type": "Optional", "value": {"type": "UFix64", "value": "8.0"}}
  ]' \
  --signer testnet-account \
  --network testnet

# 5. Mint species coins
flow transactions send cadence/transactions/mint-species-coin.cdc \
  --args-json '[
    {"type": "Address", "value": "<test-addr>"},
    {"type": "UInt64", "value": "1"}
  ]' \
  --signer testnet-account \
  --network testnet

# 6. Verify results
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc \
  --args-json '[
    {"type": "Address", "value": "<test-addr>"},
    {"type": "UInt64", "value": "1"}
  ]' \
  --network testnet

flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc \
  --args-json '[
    {"type": "Address", "value": "<test-addr>"}
  ]' \
  --network testnet
```

### Test FishCard Flow
```bash
# 1. Set up FishCard collection
flow transactions send cadence/transactions/setup_fish_card_collection.cdc --signer testnet-account --network testnet

# 2. Enable FishCard minting for NFT
flow transactions send cadence/transactions/enable_fish_cards.cdc \
  --args-json '[
    {"type": "UInt64", "value": "1"}
  ]' \
  --signer testnet-account \
  --network testnet

# 3. Commit FishCard mint with salt
flow transactions send cadence/transactions/commit_fish_card.cdc \
  --args-json '[
    {"type": "UInt64", "value": "1"},
    {"type": "Address", "value": "<test-addr>"},
    {"type": "Address", "value": "<test-addr>"},
    {"type": "Array", "value": [
      {"type": "UInt8", "value": "1"},
      {"type": "UInt8", "value": "2"},
      {"type": "UInt8", "value": "3"},
      {"type": "UInt8", "value": "4"},
      {"type": "UInt8", "value": "5"},
      {"type": "UInt8", "value": "6"},
      {"type": "UInt8", "value": "7"},
      {"type": "UInt8", "value": "8"}
    ]}
  ]' \
  --signer testnet-account \
  --network testnet

# 4. Wait at least 1 block (2-3 seconds on testnet)

# 5. Reveal FishCard
flow transactions send cadence/transactions/reveal_fish_card.cdc \
  --args-json '[
    {"type": "UInt64", "value": "0"}
  ]' \
  --signer testnet-account \
  --network testnet

# 6. Verify FishCard
flow scripts execute cadence/scripts/get_fish_card_by_id.cdc \
  --args-json '[
    {"type": "Address", "value": "<test-addr>"},
    {"type": "UInt64", "value": "1"}
  ]' \
  --network testnet
```

### Transfer Testing
```bash
# Transfer FishCard
flow transactions send cadence/transactions/transfer_fish_card.cdc \
  --args-json '[
    {"type": "Address", "value": "<recipient-addr>"},
    {"type": "UInt64", "value": "1"}
  ]' \
  --signer testnet-account \
  --network testnet

# Transfer BaitCoin
flow transactions send cadence/transactions/transfer_baitcoin.cdc \
  --args-json '[
    {"type": "Address", "value": "<recipient-addr>"},
    {"type": "UFix64", "value": "10.0"}
  ]' \
  --signer testnet-account \
  --network testnet
```

### System Health Checks
```bash
# Get a complete overview of an account's DerbyFish assets
echo "=== FISH NFTs ==="
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc \
  --args-json '[
    {"type": "Address", "value": "<test-addr>"}
  ]' \
  --network testnet

echo "=== WALLEYE COINS ==="
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc \
  --args-json '[
    {"type": "Address", "value": "<test-addr>"}
  ]' \
  --network testnet

echo "=== BAITCOIN ==="
flow scripts execute cadence/scripts/get_bc_balance.cdc \
  --args-json '[
    {"type": "Address", "value": "<test-addr>"}
  ]' \
  --network testnet

echo "=== FUSD ==="
flow scripts execute cadence/scripts/get_fusd_balance.cdc \
  --args-json '[
    {"type": "Address", "value": "<test-addr>"}
  ]' \
  --network testnet

echo "=== REGISTERED SPECIES ==="
flow scripts execute cadence/scripts/get_registered_species.cdc --network testnet

echo "=== FISHCARDS ==="
flow scripts execute cadence/scripts/get_fish_card_ids.cdc \
  --args-json '[
    {"type": "Address", "value": "<test-addr>"}
  ]' \
  --network testnet
```

---

## 🚨 Common Issues & Troubleshooting

### Account Not Set Up
**Error:** "Could not borrow FishNFT collection"
**Solution:** Run setup transaction first:
```bash
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc \
  --signer testnet-account \
  --network testnet
```

### NFT Not Found
**Error:** "NFT with ID X not found"
**Solution:** Check available IDs first:
```bash
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc <address> --network testnet
```

### Species Not Registered
**Error:** Species code validation fails
**Solution:** Register species or use existing code:
```bash
flow scripts execute cadence/scripts/get_registered_species.cdc --network testnet
```

### Insufficient Balance
**Error:** Transfer/swap fails
**Solution:** Check balances and get testnet tokens:
1. Visit Flow Testnet Faucet: https://testnet-faucet.onflow.org/
2. Fund your account with testnet FLOW tokens
3. Check balance:
```bash
flow scripts execute cadence/scripts/get_fusd_balance.cdc <address> --network testnet
```

### FishCard Commit-Reveal Issues
**Error:** "Must wait at least 1 block to reveal"
**Solution:** Wait 2-3 seconds between commit and reveal on testnet

### Network Connection Issues
**Error:** "Could not connect to testnet"
**Solution:** Verify Flow CLI configuration:
```bash
flow config add testnet-account --network testnet --signer testnet-account
```

---

## 📊 System Health Checks

### Complete Account Overview
```bash
# Get a complete overview of an account's DerbyFish assets
echo "=== FISH NFTs ==="
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc <test-addr> --network testnet

echo "=== WALLEYE COINS ==="
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc <test-addr> --network testnet

echo "=== BAITCOIN ==="
flow scripts execute cadence/scripts/get_bc_balance.cdc <test-addr> --network testnet

echo "=== FUSD ==="
flow scripts execute cadence/scripts/get_fusd_balance.cdc <test-addr> --network testnet

echo "=== REGISTERED SPECIES ==="
flow scripts execute cadence/scripts/get_registered_species.cdc --network testnet

echo "=== FISHCARDS ==="
flow scripts execute cadence/scripts/get_fish_card_ids.cdc <test-addr> --network testnet
```

---

## 🔍 What Each Test Validates

| Function | Tests | What To Look For |
|----------|-------|------------------|
| `get_fish_nft_by_id.cdc` | NFT metadata integrity | Complete metadata, correct species code, valid timestamps |
| `get_walleye_coin_info.cdc` | WalleyeCoin contract health | Vault setup, token metadata, total supply accuracy |
| `get_walleye_coin_all_metadata.cdc` | Complete species data profile | All metadata fields populated, regional data, conservation status |
| `get_fish_card_by_id.cdc` | FishCard data | Revealed fields, rarity, parent NFT connection |
| `get_registered_species.cdc` | Species registry | Proper species registration, contract mapping |
| Transfer functions | Cross-account functionality | Successful asset transfers, balance updates |
| Setup functions | Account initialization | Proper vault/collection creation |

---

**Note:** Always include `--network testnet` flag for all commands when testing on Flow testnet.
