# DerbyFish Testing Functions Guide

This document provides comprehensive testing commands for all parts of the DerbyFish ecosystem after deployment.

---

## 🎣 NFT Testing

### Get Specific NFT by ID
```bash
# Get detailed information about a specific Fish NFT
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc <angler_address> <nft_id>

# Example:
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc 0x179b6b1cb6755e31 1
```

**Returns:** Complete NFT metadata including:
- Core catch data (species, length, weight, timestamp)
- Location data (coordinates, water body)
- Media (bump shot, hero shot, release video)
- Verification status
- Species code for coin minting

### Get All NFT IDs for Account
```bash
# List all Fish NFT IDs owned by an account
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc <angler_address>

# Example:
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc 0x179b6b1cb6755e31
```

---

## 🪙 WalleyeCoin Testing

### Basic Balance Check
```bash
# Get WalleyeCoin balance for an account
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc <address>

# Example:
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc 0x179b6b1cb6755e31
```

### Comprehensive WalleyeCoin Information
```bash
# Get detailed WalleyeCoin contract metadata and account info
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc <address>

# Example:
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc 0x179b6b1cb6755e31
```

**Returns:** 
- Vault setup status
- Balance information
- Public capability status
- Interface compliance

### Complete WalleyeCoin Metadata Profile
```bash
# Get ALL WalleyeCoin metadata - comprehensive species data dump
flow scripts execute cadence/scripts/get_walleye_coin_all_metadata.cdc

# No parameters needed - returns everything!
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
flow scripts execute cadence/scripts/get_species_coin_balance.cdc <address> <ticker>

# Examples:
flow scripts execute cadence/scripts/get_species_coin_balance.cdc 0x179b6b1cb6755e31 "SANVIT"
flow scripts execute cadence/scripts/get_species_coin_balance.cdc 0x179b6b1cb6755e31 "EXFISH"
```

---

## 🐟 Species Registry Testing

### Check Registered Species
```bash
# Get all registered species in the system
flow scripts execute cadence/scripts/get_registered_species.cdc
```

**Returns:** Complete list of species codes and their contract addresses

---

## 💰 BaitCoin & FUSD Testing

### BaitCoin Balance
```bash
# Get BaitCoin balance
flow scripts execute cadence/scripts/get_bc_balance.cdc <address>

# Example:
flow scripts execute cadence/scripts/get_bc_balance.cdc 0x179b6b1cb6755e31
```

### FUSD Balance
```bash
# Get FUSD balance
flow scripts execute cadence/scripts/get_fusd_balance.cdc <address>

# Example:
flow scripts execute cadence/scripts/get_fusd_balance.cdc 0x179b6b1cb6755e31
```

### Contract FUSD Balance
```bash
# Get FUSD balance held by a contract
flow scripts execute cadence/scripts/get_contract_fusd_balance.cdc
```

---

## 🔄 Transfer Testing

### Transfer Fish NFT
```bash
# Transfer a Fish NFT between accounts
flow transactions send cadence/transactions/transfer_fish_nft.cdc <recipient_address> <nft_id> \
  --signer <current_owner> \
  --network emulator

# Example:
flow transactions send cadence/transactions/transfer_fish_nft.cdc 0x01cf0e2f2f715450 1 \
  --signer test-acct \
  --network emulator
```

### Transfer BaitCoin
```bash
# Transfer BaitCoin between accounts
flow transactions send cadence/transactions/transfer_baitcoin.cdc <recipient_address> <amount> \
  --signer <sender> \
  --network emulator

# Example:
flow transactions send cadence/transactions/transfer_baitcoin.cdc 0x01cf0e2f2f715450 10.0 \
  --signer test-acct \
  --network emulator
```

---

## 💱 Token Swap Testing

### FUSD to BaitCoin Swap
```bash
# Swap FUSD for BaitCoin
flow transactions send cadence/transactions/swap_fusd_for_baitcoin.cdc <fusd_amount> \
  --signer <account> \
  --network emulator

# Example:
flow transactions send cadence/transactions/swap_fusd_for_baitcoin.cdc 100.0 \
  --signer test-acct \
  --network emulator
```

### BaitCoin to FUSD Swap
```bash
# Swap BaitCoin for FUSD
flow transactions send cadence/transactions/swap_baitcoin_for_fusd.cdc <baitcoin_amount> \
  --signer <account> \
  --network emulator

# Example:
flow transactions send cadence/transactions/swap_baitcoin_for_fusd.cdc 50.0 \
  --signer test-acct \
  --network emulator
```

---

## 🏗️ Account Setup Testing

### Setup Fish NFT Collection
```bash
# Set up Fish NFT collection for an account
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc \
  --signer <account> \
  --network emulator

# Verify setup
flow scripts execute cadence/scripts/check_nft_collection.cdc <account>
```

**Verifies:**
- Collection exists at correct storage path
- Public capability exposed with required interfaces
- Ready to receive NFTs

### Setup WalleyeCoin Vault
```bash
# Set up WalleyeCoin vault for an account
flow transactions send cadence/transactions/setup_walleye_coin_account.cdc \
  --signer <account> \
  --network emulator

# Verify setup
flow scripts execute cadence/scripts/check_walleye_setup.cdc <account>
```

**Verifies:**
- Vault exists at correct storage path
- Public capability exposed with Receiver and Balance interfaces
- Ready to receive WalleyeCoin

### Setup Species Coin Vault (Generic)
```bash
# Set up vault for any species coin
flow transactions send cadence/transactions/setup_species_coin_account.cdc \
  --signer <account> \
  --network emulator
```

### Setup BaitCoin Account
```bash
# Set up BaitCoin vault
flow transactions send cadence/transactions/setup_bc_account.cdc \
  --signer <account> \
  --network emulator
```

### Setup FUSD Account
```bash
# Set up FUSD vault
flow transactions send cadence/transactions/setup_fusd_account.cdc \
  --signer <account> \
  --network emulator
```

---

## 🧪 Advanced Testing Scenarios

### Test Complete Catch Flow
```bash
# 1. Mint Fish NFT with metadata
flow transactions send cadence/transactions/mint_fish_nft_with_species.cdc \
  --args-json '[
    {"type":"Address","value":"0x179b6b1cb6755e31"},
    {"type":"String","value":"Walleye"},
    {"type":"String","value":"Sander vitreus"},
    {"type":"UFix64","value":"26.0"},
    {"type":"Optional","value":{"type":"UFix64","value":"8.5"}},
    {"type":"UFix64","value":"1699123456.0"},
    {"type":"Bool","value":true},
    {"type":"String","value":"https://example.com/walleye-bump.jpg"},
    {"type":"String","value":"https://example.com/walleye-hero.jpg"},
    {"type":"String","value":"hash123"},
    {"type":"String","value":"hash456"},
    {"type":"Optional","value":{"type":"String","value":"https://example.com/walleye-release.mp4"}},
    {"type":"Optional","value":{"type":"String","value":"hash789"}},
    {"type":"Fix64","value":"-93.2650"},
    {"type":"Fix64","value":"44.9778"},
    {"type":"Optional","value":{"type":"String","value":"Lake Minnetonka, MN"}},
    {"type":"String","value":"SANDER_VITREUS"}
  ]' \
  --signer emulator-account \
  --network emulator

# 2. Check results
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc 0x179b6b1cb6755e31 1
```

### Test Species Registration
```bash
# Register a new species manually
flow transactions send cadence/transactions/register_species.cdc "EXAMPLE_FISH" 0xf8d6e0586b0a20c7 \
  --signer emulator-account \
  --network emulator

# Check registration
flow scripts execute cadence/scripts/get_registered_species.cdc
```

### Test Token Economy Integration
```bash
# 1. Mint FUSD for testing
flow transactions send cadence/transactions/mint_fusd.cdc 0x179b6b1cb6755e31 1000.0 \
  --signer emulator-account \
  --network emulator

# 2. Check FUSD balance
flow scripts execute cadence/scripts/get_fusd_balance.cdc 0x179b6b1cb6755e31

# 3. Swap some for BaitCoin
flow transactions send cadence/transactions/swap_fusd_for_baitcoin.cdc 100.0 \
  --signer test-acct \
  --network emulator

# 4. Check BaitCoin balance
flow scripts execute cadence/scripts/get_bc_balance.cdc 0x179b6b1cb6755e31
```

---

## 📊 System Health Checks

### Total Supply Check
```bash
# Get total supply of any token
flow scripts execute cadence/scripts/get_total_supply.cdc
```

### Complete Account Overview
```bash
# Get a complete overview of an account's DerbyFish assets
echo "=== FISH NFTs ==="
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc 0x179b6b1cb6755e31

echo "=== WALLEYE COINS ==="
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc 0x179b6b1cb6755e31

echo "=== BAITCOIN ==="
flow scripts execute cadence/scripts/get_bc_balance.cdc 0x179b6b1cb6755e31

echo "=== FUSD ==="
flow scripts execute cadence/scripts/get_fusd_balance.cdc 0x179b6b1cb6755e31

echo "=== REGISTERED SPECIES ==="
flow scripts execute cadence/scripts/get_registered_species.cdc
```

---

## 🔍 What Each Test Validates

| Function | Tests | What To Look For |
|----------|-------|------------------|
| `get_fish_nft_by_id.cdc` | NFT metadata integrity | Complete metadata, correct species code, valid timestamps |
| `get_walleye_coin_info.cdc` | WalleyeCoin contract health | Vault setup, token metadata, total supply accuracy |
| `get_walleye_coin_all_metadata.cdc` | Complete species data profile | All metadata fields populated, regional data, conservation status |
| `test_walleye_nft.cdc` | Species-specific analysis | Catch statistics, location data, release rates |
| `get_registered_species.cdc` | Species registry | Proper species registration, contract mapping |
| Transfer functions | Cross-account functionality | Successful asset transfers, balance updates |
| Swap functions | Token economy | Exchange rates, liquidity, balance changes |
| Setup functions | Account initialization | Proper vault/collection creation |

---

## 🚨 Common Issues & Troubleshooting

### Account Not Set Up
**Error:** "Could not borrow FishNFT collection"
**Solution:** Run setup transaction first:
```bash
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --signer <account>
```

### NFT Not Found
**Error:** "NFT with ID X not found"
**Solution:** Check available IDs first:
```bash
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc <address>
```

### Species Not Registered
**Error:** Species code validation fails
**Solution:** Register species or use existing code:
```bash
flow scripts execute cadence/scripts/get_registered_species.cdc
```

### Insufficient Balance
**Error:** Transfer/swap fails
**Solution:** Check balances and mint tokens if needed:
```bash
flow transactions send cadence/transactions/mint_fusd.cdc <address> <amount> --signer emulator-account
```

---

**Next Steps:** Use these functions to comprehensively test your DerbyFish deployment and validate all system interactions work correctly!
