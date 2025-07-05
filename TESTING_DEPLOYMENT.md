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

# Check specific NFT details
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc \
  --args-json '[
    {"type": "Address", "value": "0x179b6b1cb6755e31"},
    {"type": "UInt64", "value": "1"}
  ]'

# Check species coin balance
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc \
  --args-json '[{"type": "Address", "value": "0x179b6b1cb6755e31"}]'
```

### 6. Set Up FishCard NFT Collection and Mint FishCards

```bash
# Set up FishCard NFT collection for test account
flow transactions send cadence/transactions/setup_fish_card_collection.cdc --signer test-acct

# Enable fish card minting for your FishNFT (one-time setup per NFT)
flow transactions send cadence/transactions/enable_fish_cards.cdc \
  --args-json '[
    {"type": "UInt64", "value": "1"}
  ]' \
  --signer test-acct

# COMMIT-REVEAL MINTING (Secure randomness)
# Step 1: Commit - provide user salt for randomness
flow transactions send cadence/transactions/commit_fish_card.cdc \
  --args-json '[
    {"type": "UInt64", "value": "1"},
    {"type": "Address", "value": "0x179b6b1cb6755e31"},
    {"type": "Address", "value": "0x179b6b1cb6755e31"},
    {"type": "Array", "value": [{"type": "UInt8", "value": "1"}, {"type": "UInt8", "value": "2"}, {"type": "UInt8", "value": "3"}, {"type": "UInt8", "value": "4"}, {"type": "UInt8", "value": "5"}, {"type": "UInt8", "value": "6"}, {"type": "UInt8", "value": "7"}, {"type": "UInt8", "value": "8"}]}
  ]' \
  --signer test-acct

# Step 2: Wait at least 1 block, then reveal using the receipt
flow transactions send cadence/transactions/reveal_fish_card.cdc \
  --args-json '[
    {"type": "UInt64", "value": "0"}
  ]' \
  --signer test-acct

# Verify FishCard collection
flow scripts execute cadence/scripts/get_fish_card_ids.cdc \
  --args-json '[{"type": "Address", "value": "0x179b6b1cb6755e31"}]'

# Check specific FishCard details and revealed fields
flow scripts execute cadence/scripts/get_fish_card_by_id.cdc \
  --args-json '[
    {"type": "Address", "value": "0x179b6b1cb6755e31"},
    {"type": "UInt64", "value": "1"}
  ]'
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

### FishCard NFT System
- **FishCard NFT Contract**: 
  - Creates randomized trading cards from existing FishNFTs
  - Uses **commit-reveal scheme** with Xorshift128plus for secure randomness
  - Each card randomly reveals fishing data fields via independent coin flips
  - Two-phase minting: Commit (with user salt) → Wait (≥1 block) → Reveal & Mint
  - No payment required - anyone can mint cards from enabled FishNFTs
  - Cards show core data (species, length, etc.) but hide/reveal private data randomly

### FishCard Features
- **Secure Randomness**: Uses user-provided salt + future block hash for unbiased results
- **Independent Coin Flips**: Each non-core field gets its own 50/50 chance to be revealed
- **Rarity System**: Cards with more revealed fields are rarer (Common → Legendary)
- **Privacy Protection**: Sensitive location/angler data only revealed based on chance
- **NFT Integration**: Must own a FishNFT and enable card minting per NFT
- **Anti-Manipulation**: Commit-reveal prevents users from cherry-picking favorable outcomes

## Transaction Status

| Transaction | Status | Purpose |
|-------------|---------|---------|
| `setup_walleye_coin_account.cdc` | ✅ Working | Set up species coin vault |
| `register_species.cdc` | ✅ Working | Register species in FishNFT |
| `mint_fish_nft_with_species.cdc` | ✅ Working | Mint NFT with full metadata |
| `mint_fish_nft.cdc` | ✅ Working | Mint NFT with basic metadata |
| `mint-species-coin.cdc` | ✅ Working | Mint species coins from NFT |
| `setup_fish_card_collection.cdc` | ✅ Working | Set up FishCard NFT collection |
| `enable_fish_cards.cdc` | ✅ Working | Enable fish card minting for FishNFT |
| `commit_fish_card.cdc` | ✅ Working | Commit FishCard mint with user salt |
| `reveal_fish_card.cdc` | ✅ Working | Reveal and mint FishCard using receipt |

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

### FishCard-Specific Issues
5. **"FishCard minting not enabled for this Fish NFT"**
   - Solution: Run `enable_fish_cards.cdc` for the NFT first

6. **"Could not borrow Fish NFT collection from owner"**
   - Solution: Ensure the NFT owner has set up their collection properly

7. **"Could not borrow FishCard collection"**
   - Solution: Run `setup_fish_card_collection.cdc` first

8. **"Commit not found"**
   - Solution: Ensure you've run `commit_fish_card.cdc` first and saved the receipt ID

9. **"Must wait at least 1 block to reveal"**
   - Solution: Wait for at least 1 block after committing before revealing

10. **"Could not borrow FishCard minter"**
    - Solution: This indicates a contract deployment issue

## Testing Scenarios

### Basic Flow Test
1. Set up account → Register species → Mint NFT → Mint coins → Verify

### Duplicate Prevention Test
1. Mint NFT → Mint coins → Try to mint coins again
2. Expected: Species coin contract prevents duplicate minting

### Cross-Species Test
1. Mint non-Walleye NFT → Try to mint WalleyeCoin
2. Expected: Transaction fails with species mismatch error

### FishCard Flow Test
1. Set up FishCard collection → Enable fish card minting → Commit with user salt → Wait ≥1 block → Reveal & mint
2. Expected: FishCard NFT is minted with randomly revealed fishing data based on commit-reveal randomness

### FishCard Randomness Test
1. Commit multiple FishCards from the same FishNFT with different user salts → Reveal each after ≥1 block
2. Expected: Each card reveals different combinations of fishing data fields due to different salt/block combinations

### FishCard Security Test
1. Try to reveal a commit immediately without waiting for next block
2. Expected: Transaction fails with "Must wait at least 1 block to reveal" error

## Notes
- Species coins now handle all duplicate prevention logic
- FishNFT contract is simplified and focused on NFT functionality
- Each species coin contract maintains its own list of redeemed NFTs
- **FishCard system uses commit-reveal for secure randomness**:
  - Users provide salt at commit time
  - System uses future block hash + salt for unpredictable randomness
  - Prevents manipulation while ensuring fairness
- **Core vs Non-Core Fields**:
  - Core fields (species, length, timestamp, etc.) always revealed
  - Non-core fields (location, gear, technique, etc.) have 50/50 reveal chance
  - Each field gets independent coin flip for maximum variety
- The system is more modular and easier to maintain
