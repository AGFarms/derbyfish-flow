# DerbyFish Flow Testnet Guide

## Overview
This guide covers testing the DerbyFish Flow contracts on the **Flow Testnet**. The system has been simplified:
- **FishNFT**: Handles NFT minting and species registration (no redemption tracking)
- **Species Coins**: Handle their own tracking of which NFTs have been used for minting

## Quick Start - Working Flow ✅

### 0. Prerequisites
```bash
# Configure your Flow CLI for testnet
flow config add testnet-account --network testnet --signer testnet-account

# Fund your testnet account with testnet FLOW tokens
# Visit the Flow Testnet Faucet: https://testnet-faucet.onflow.org/
```

### 1. Set Up Your Account
```bash
# Set up NFT collection
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --network testnet --signer testnet-account

# Set up WalleyeCoin vault
flow transactions send cadence/transactions/setup_walleye_coin_account.cdc --network testnet --signer testnet-account
```

### 2. Register Species (One-time setup)
```bash
# Register the Walleye species
flow transactions send cadence/transactions/register_species.cdc \
  --args-json '[
    {"type": "String", "value": "SANDER_VITREUS"},
    {"type": "Address", "value": "YOUR_TESTNET_CONTRACT_ADDRESS"}
  ]' \
  --network testnet \
  --signer testnet-account
```

### 3. Mint Fish NFT
```bash
# Mint a comprehensive Fish NFT (44 parameters)
flow transactions send cadence/transactions/mint_fish_nft_with_species.cdc \
  --args-json '[
    {"type": "Address", "value": "YOUR_TESTNET_ADDRESS"},
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
  --network testnet \
  --signer testnet-account
```

### 4. Mint Species Coins (Separate Transaction)
```bash
# Mint species coins using the NFT
flow transactions send cadence/transactions/mint-species-coin.cdc \
  --args-json '[
    {"type": "Address", "value": "YOUR_TESTNET_ADDRESS"},
    {"type": "UInt64", "value": "1"}
  ]' \
  --network testnet \
  --signer testnet-account
```

### 5. Verify Results
```bash
# Check NFT collection
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc \
  --args-json '[{"type": "Address", "value": "YOUR_TESTNET_ADDRESS"}]' \
  --network testnet

# Check specific NFT details
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc \
  --args-json '[
    {"type": "Address", "value": "YOUR_TESTNET_ADDRESS"},
    {"type": "UInt64", "value": "1"}
  ]' \
  --network testnet

# Check species coin balance
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc \
  --args-json '[{"type": "Address", "value": "YOUR_TESTNET_ADDRESS"}]' \
  --network testnet
```

### 6. Set Up FishCard NFT Collection and Mint FishCards

```bash
# Set up FishCard NFT collection for test account
flow transactions send cadence/transactions/setup_fish_card_collection.cdc \
  --network testnet \
  --signer testnet-account

# Enable fish card minting for your FishNFT (one-time setup per NFT)
flow transactions send cadence/transactions/enable_fish_cards.cdc \
  --args-json '[
    {"type": "UInt64", "value": "1"}
  ]' \
  --network testnet \
  --signer testnet-account

# COMMIT-REVEAL MINTING (Secure randomness)
# Step 1: Commit - provide user salt for randomness
flow transactions send cadence/transactions/commit_fish_card.cdc \
  --args-json '[
    {"type": "UInt64", "value": "1"},
    {"type": "Address", "value": "YOUR_TESTNET_ADDRESS"},
    {"type": "Address", "value": "YOUR_TESTNET_ADDRESS"},
    {"type": "Array", "value": [{"type": "UInt8", "value": "1"}, {"type": "UInt8", "value": "2"}, {"type": "UInt8", "value": "3"}, {"type": "UInt8", "value": "4"}, {"type": "UInt8", "value": "5"}, {"type": "UInt8", "value": "6"}, {"type": "UInt8", "value": "7"}, {"type": "UInt8", "value": "8"}]}
  ]' \
  --network testnet \
  --signer testnet-account

# Step 2: Wait at least 1 block, then reveal using the receipt
flow transactions send cadence/transactions/reveal_fish_card.cdc \
  --args-json '[
    {"type": "UInt64", "value": "0"}
  ]' \
  --network testnet \
  --signer testnet-account

# Verify FishCard collection
flow scripts execute cadence/scripts/get_fish_card_ids.cdc \
  --args-json '[{"type": "Address", "value": "YOUR_TESTNET_ADDRESS"}]' \
  --network testnet

# Check specific FishCard details and revealed fields
flow scripts execute cadence/scripts/get_fish_card_by_id.cdc \
  --args-json '[
    {"type": "Address", "value": "YOUR_TESTNET_ADDRESS"},
    {"type": "UInt64", "value": "1"}
  ]' \
  --network testnet
```

### 7. Transfer FishCards Between Accounts

```bash
# First ensure the recipient has a FishCard collection set up
flow transactions send cadence/transactions/setup_fish_card_collection.cdc \
  --network testnet \
  --signer recipient-account

# Transfer a FishCard from test-acct to recipient-acct
flow transactions send cadence/transactions/transfer_fish_card.cdc \
  --args-json '[
    {"type": "Address", "value": "RECIPIENT_TESTNET_ADDRESS"},
    {"type": "UInt64", "value": "1"}
  ]' \
  --network testnet \
  --signer testnet-account

# Verify the transfer
flow scripts execute cadence/scripts/get_fish_card_ids.cdc \
  --args-json '[{"type": "Address", "value": "RECIPIENT_TESTNET_ADDRESS"}]' \
  --network testnet

# Check specific FishCard details
flow scripts execute cadence/scripts/get_fish_card_by_id.cdc \
  --args-json '[
    {"type": "Address", "value": "RECIPIENT_TESTNET_ADDRESS"},
    {"type": "UInt64", "value": "1"}
  ]' \
  --network testnet
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
| `transfer_fish_card.cdc` | ✅ Working | Transfer FishCard between accounts |

## Error Handling

### Common Issues
1. **"Species code not registered"**
   - Solution: Run `register_species.cdc` first with `--network testnet`

2. **"Could not borrow recipient species coin vault"**
   - Solution: Run `setup_walleye_coin_account.cdc` first with `--network testnet`

3. **"Fish NFT is not a Walleye"**
   - Solution: Only Walleye NFTs (SANDER_VITREUS) can mint WalleyeCoin

4. **"Could not borrow Fish NFT"**
   - Solution: Ensure the NFT ID exists and belongs to the recipient

5. **"Account not found" or "Invalid address"**
   - Solution: Ensure you're using valid testnet addresses and have funded your testnet account

6. **"Insufficient balance"**
   - Solution: Visit the Flow Testnet Faucet to get more testnet FLOW tokens

### FishCard-Specific Issues
7. **"FishCard minting not enabled for this Fish NFT"**
   - Solution: Run `enable_fish_cards.cdc` for the NFT first with `--network testnet`

8. **"Could not borrow Fish NFT collection from owner"**
   - Solution: Ensure the NFT owner has set up their collection properly on testnet

9. **"Could not borrow FishCard collection"**
   - Solution: Run `setup_fish_card_collection.cdc` first with `--network testnet`

10. **"Commit not found"**
    - Solution: Ensure you've run `commit_fish_card.cdc` first and saved the receipt ID

11. **"Must wait at least 1 block to reveal"**
    - Solution: Wait for at least 1 block after committing before revealing (about 2-3 seconds on testnet)

12. **"Could not borrow FishCard minter"**
    - Solution: This indicates a contract deployment issue on testnet

## Testing Scenarios

### Basic Flow Test
1. Set up testnet account → Register species → Mint NFT → Mint coins → Verify
2. Note: All transactions must include `--network testnet`

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
- **Testnet-Specific Notes**:
  - Always use `--network testnet` flag with Flow CLI commands
  - Fund your account using the Flow Testnet Faucet
  - Block times are ~2-3 seconds on testnet
  - Keep your testnet private keys secure but remember they're for testing only
  - Contract addresses will be different on testnet vs mainnet

