# DerbyFish Flow Testing Guide

## Overview
This guide covers testing the DerbyFish Flow contracts on the **Flow Emulator**. The system has been simplified:
- **FishNFT**: Handles NFT minting and species registration (no redemption tracking)
- **Species Coins**: Handle their own tracking of which NFTs have been used for minting

## Quick Start - Working Flow ✅

### 1. Set Up Your Account
```bash
# Set up NFT collection
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --signer test-acct

# Set up WalleyeCoin vault
flow transactions send cadence/transactions/setup_walleye_coin_account.cdc --signer test-acct
```

### 2. Register Species (One-time setup)
```bash
# Register the Walleye species
flow transactions send cadence/transactions/register_species.cdc \
  --args-json '[
    {"type": "String", "value": "SANDER_VITREUS"},
    {"type": "Address", "value": "0xf8d6e0586b0a20c7"}
  ]' \
  --signer emulator-account
```

### 3. Mint Fish NFT
```bash
# Mint a comprehensive Fish NFT (44 parameters - CORRECTED)
flow transactions send cadence/transactions/mint_fish_nft_with_species.cdc \
  --args-json '[
    {"type": "Address", "value": "0x179b6b1cb6755e31"},
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
  --signer emulator-account
```

### 4. Mint Species Coins (Separate Transaction)
```bash
# Mint species coins using the NFT
flow transactions send cadence/transactions/mint-species-coin.cdc \
  --args-json '[
    {"type": "Address", "value": "0x179b6b1cb6755e31"},
    {"type": "UInt64", "value": "1"}
  ]' \
  --signer emulator-account
```

### 5. Verify Results
```bash
# Check NFT collection
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc \
  --args-json '[{"type": "Address", "value": "0x179b6b1cb6755e31"}]'

# Check species coin balance
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc \
  --args-json '[{"type": "Address", "value": "0x179b6b1cb6755e31"}]'
```

## System Architecture

### Simplified Design
- **FishNFT Contract**: 
  - Mints NFTs with comprehensive metadata
  - Maintains species registry (for reference)
  - ❌ No longer tracks redemption status
  
- **Species Coin Contracts** (e.g., WalleyeCoin):
  - Handle their own tracking of which NFTs have been used
  - Prevent duplicate minting through internal logic
  - Maintain lists of redeemed NFTs independently

### Key Changes
1. **Removed SpeciesCoinRedeemer interface** from FishNFT
2. **Removed redemption tracking** (`hasBeenRedeemedForCoin`, `markAsRedeemedForCoin`)
3. **Removed automatic species coin minting** from NFT minting process
4. **Species coins are now fully independent** - they track their own NFT usage

## Transaction Status

| Transaction | Status | Purpose |
|-------------|---------|---------|
| `setup_walleye_coin_account.cdc` | ✅ Working | Set up species coin vault |
| `register_species.cdc` | ✅ Working | Register species in FishNFT |
| `mint_fish_nft_with_species.cdc` | ✅ Working | Mint NFT with full metadata |
| `mint_fish_nft.cdc` | ✅ Working | Mint NFT with basic metadata |
| `mint-species-coin.cdc` | ✅ Working | Mint species coins from NFT |

## Error Handling

### Common Issues
1. **"Species code not registered"**
   - Solution: Run `register_species.cdc` first

2. **"Could not borrow recipient species coin vault"**
   - Solution: Run `setup_walleye_coin_account.cdc` first

3. **"Fish NFT is not a Walleye"**
   - Solution: Only Walleye NFTs (SANDER_VITREUS) can mint WalleyeCoin

4. **"Could not borrow Fish NFT"**
   - Solution: Ensure the NFT ID exists and belongs to the recipient

## Testing Scenarios

### Basic Flow Test
1. Set up account → Register species → Mint NFT → Mint coins → Verify

### Duplicate Prevention Test
1. Mint NFT → Mint coins → Try to mint coins again
2. Expected: Species coin contract prevents duplicate minting

### Cross-Species Test
1. Mint non-Walleye NFT → Try to mint WalleyeCoin
2. Expected: Transaction fails with species mismatch error

## Notes
- Species coins now handle all duplicate prevention logic
- FishNFT contract is simplified and focused on NFT functionality
- Each species coin contract maintains its own list of redeemed NFTs
- The system is more modular and easier to maintain
