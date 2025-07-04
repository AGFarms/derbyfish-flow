# Flow CLI Testing & Deployment Guide

This guide walks you through a typical local development workflow for DerbyFish using the Flow CLI. It covers starting the emulator, deploying contracts, creating a test account, setting up NFT and species coin vaults, minting Fish NFTs with automatic species coin minting, retroactive species coin minting, and querying balances.

---

## 1. Start the Flow Emulator

```sh
flow emulator start
```

Leave this running in a separate terminal window.

---

## 2. Deploy Contracts

```sh
flow project deploy
```

This will deploy all contracts defined in your `flow.json` to the emulator.

---

## 3. Create a Test Account

```sh
flow accounts create
```

Name the account `test-acct`.

---

## 4. Set Up NFT Collection for Test Account

```sh
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --signer test-acct
```

---

## 5. Set Up WalleyeCoin Vault for Test Account

```sh
flow transactions send cadence/transactions/setup_walleye_coin_account.cdc --signer test-acct
```

---

## 6. Mint Fish NFT with Automatic Species Coin Minting (Comprehensive Transaction)

### **Recommended: All-in-One Transaction**

This transaction handles everything: species registration, Fish NFT minting, and species coin minting in one transaction:

```sh
flow transactions send cadence/transactions/mint_fish_and_species_coins.cdc \
  --args-json '[
    {"type":"Address","value":"0x179b6b1cb6755e31"},
    {"type":"String","value":"https://example.com/walleye-bump.jpg"},
    {"type":"String","value":"https://example.com/walleye-hero.jpg"},
    {"type":"Bool","value":true},
    {"type":"Optional","value":{"type":"String","value":"https://example.com/walleye-release.mp4"}},
    {"type":"String","value":"hash123"},
    {"type":"String","value":"hash456"},
    {"type":"Optional","value":{"type":"String","value":"hash789"}},
    {"type":"Fix64","value":"-93.2650"},
    {"type":"Fix64","value":"44.9778"},
    {"type":"UFix64","value":"26.0"},
    {"type":"String","value":"Walleye"},
    {"type":"String","value":"Sander vitreus"},
    {"type":"UFix64","value":"1699123456.0"},
    {"type":"Optional","value":{"type":"String","value":"Jig and minnow"}},
    {"type":"Optional","value":{"type":"String","value":"Lake Minnetonka, MN"}},
    {"type":"String","value":"SANDER_VITREUS"}
  ]' \
  --signer emulator-account \
  --network emulator
```

**What this transaction does:**
1. ✅ Auto-registers "SANDER_VITREUS" species if not already registered
2. ✅ Mints Fish NFT with species code stored in metadata
3. ✅ Deposits Fish NFT to recipient's account
4. ✅ Mints 1.0 SANVIT species coins via WalleyeCoin's `processCatchFromNFT`
5. ✅ Deposits species coins to recipient's account
6. ✅ Marks NFT as having species coins minted (prevents double-minting)

### **Alternative: Step-by-Step Approach**

If you prefer to handle each step separately:

#### 6a. Register Species (Manual)
```sh
flow transactions send cadence/transactions/register_species.cdc "SANDER_VITREUS" 0xf8d6e0586b0a20c7 --signer emulator-account --network emulator
```

#### 6b. Mint Fish NFT Only
```sh
flow transactions send cadence/transactions/mint_fish_nft_with_species.cdc \
  --args-json '[
    {"type":"Address","value":"0x179b6b1cb6755e31"},
    {"type":"String","value":"https://example.com/walleye-bump.jpg"},
    {"type":"String","value":"https://example.com/walleye-hero.jpg"},
    {"type":"Bool","value":true},
    {"type":"Optional","value":{"type":"String","value":"https://example.com/walleye-release.mp4"}},
    {"type":"String","value":"hash123"},
    {"type":"String","value":"hash456"},
    {"type":"Optional","value":{"type":"String","value":"hash789"}},
    {"type":"Fix64","value":"-93.2650"},
    {"type":"Fix64","value":"44.9778"},
    {"type":"UFix64","value":"26.0"},
    {"type":"String","value":"Walleye"},
    {"type":"String","value":"Sander vitreus"},
    {"type":"UFix64","value":"1699123456.0"},
    {"type":"Optional","value":{"type":"String","value":"Jig and minnow"}},
    {"type":"Optional","value":{"type":"String","value":"Lake Minnetonka, MN"}},
    {"type":"String","value":"SANDER_VITREUS"}
  ]' \
  --signer emulator-account \
  --network emulator
```

#### 6c. Mint Species Coins Separately
```sh
flow transactions send cadence/transactions/mint_species_coin_for_catch.cdc \
  --args-json '[
    {"type":"Address","value":"0x179b6b1cb6755e31"},
    {"type":"UInt64","value":"1"},
    {"type":"String","value":"SANDER_VITREUS"}
  ]' \
  --signer emulator-account \
  --network emulator
```

---

## 7. NEW: Retroactive Species Coin Minting

**Use Case**: Mint species coins for Fish NFTs that were created before the species coin system was implemented, or when automatic minting failed.

### Check Minting Status First

```sh
flow scripts execute cadence/scripts/check-nft-minting-status.cdc --args-json '[{"type":"Array","value":[{"type":"UInt64","value":"1"},{"type":"UInt64","value":"2"},{"type":"UInt64","value":"3"}]}]'
```

**Example Output:**
```json
{
  "totalRequested": 3,
  "mintedCount": 1,
  "unmintedCount": 2,
  "mintingStatus": {"1": true, "2": false, "3": false},
  "unmintedNFTs": [2, 3],
  "totalMintedInContract": 5,
  "allMintedNFTIds": [1, 4, 5, 8, 12]
}
```

### Mint Coins for Existing NFTs

```sh
flow transactions send cadence/transactions/retroactive-species-coin-mint.cdc \
  --args-json '[
    {"type":"Address","value":"0x179b6b1cb6755e31"},
    {"type":"Array","value":[
      {"type":"UInt64","value":"2"},
      {"type":"UInt64","value":"3"},
      {"type":"UInt64","value":"4"}
    ]}
  ]' \
  --signer emulator-account \
  --network emulator
```

**What this transaction does:**
1. ✅ **Batch checks** which NFTs haven't had species coins minted
2. ✅ **Validates species** (only processes Walleye NFTs for WalleyeCoin)
3. ✅ **Prevents double-minting** with built-in tracking
4. ✅ **Race condition protection** with double-checks
5. ✅ **Detailed logging** showing processed vs skipped NFTs
6. ✅ **Final status report** for all requested NFTs

**Example Output:**
```
Processing 2 unminted NFTs out of 3 total
Minted 1.0 SANDER_VITREUS coins for Fish NFT #2
Fish NFT #3 is not a Walleye (LEPOMIS_MACROCHIRUS) - skipping
COMPLETED: Minted species coins for 1 Fish NFTs
SKIPPED: 1 Fish NFTs (already minted or wrong species)
Final minting status for all requested NFTs:
NFT #2: MINTED
NFT #3: NOT MINTED
NFT #4: MINTED
```

---

## 8. Check Results

### Get All FishNFT IDs for Test Account

```sh
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc --args-json '[{"type":"Address","value":"0x179b6b1cb6755e31"}]'
```

### Get Species Coin Balance

```sh
flow scripts execute cadence/scripts/get_species_coin_balance.cdc --args-json '[{"type":"Address","value":"0x179b6b1cb6755e31"}, {"type":"String","value":"SANVIT"}]'
```

### Check Registered Species

```sh
flow scripts execute cadence/scripts/get_registered_species.cdc --network emulator
```

### NEW: Check NFT Minting Status

```sh
flow scripts execute cadence/scripts/check-nft-minting-status.cdc --args-json '[{"type":"Array","value":[{"type":"UInt64","value":"1"},{"type":"UInt64","value":"2"}]}]'
```

### Get All Minted NFT IDs

```sh
flow scripts execute cadence/scripts/get_all_minted_nft_ids.cdc --network emulator
```

---

## Expected Results

After running the comprehensive transaction (Step 6):

1. **Fish NFT**: Minted with `speciesCode: "SANDER_VITREUS"` stored in metadata
2. **Species Coins**: 1.0 SANVIT automatically minted to test account  
3. **Species Registry**: "SANDER_VITREUS" registered to WalleyeCoin contract address
4. **Minting Tracking**: NFT marked as having species coins minted
5. **Events**: `FishMinted`, `SpeciesRegistered`, and WalleyeCoin minting events

**Expected Balances:**
- Fish NFTs: `[1]` (or next sequential ID)
- SANVIT coins: `1.00000000`

After running retroactive minting (Step 7):

1. **Only unminted NFTs processed**: Automatic filtering prevents double-minting
2. **Species validation**: Only Walleye NFTs mint WalleyeCoin
3. **Updated tracking**: All processed NFTs marked as minted
4. **Detailed reporting**: Clear logs of what was processed vs skipped

---

## Architecture Overview

### Enhanced Design with Tracking
```
FishNFT Contract
├── Species Registry: {String: Address}
├── Species Coin Tracking: {UInt64: Bool}  ← NEW
├── registerSpecies(code, address)
├── getSpeciesAddress(code) -> Address?
├── hasSpeciesCoinsBeenMinted(nftId) -> Bool  ← NEW
├── markSpeciesCoinsAsMinted(nftId)  ← NEW
├── getUnmintedNFTs(nftIds) -> [UInt64]  ← NEW
├── getMintingStatus(nftIds) -> {UInt64: Bool}  ← NEW
└── mintNFTWithSpeciesValidation(...)

Transaction Layer  
├── mint_fish_and_species_coins.cdc (recommended)
├── retroactive-species-coin-mint.cdc (NEW - batch retroactive)
├── mint_fish_nft_with_species.cdc (NFT only)
└── mint_species_coin_for_catch.cdc (coins only)

Script Layer
├── check-nft-minting-status.cdc (NEW - check status)
├── get_fish_nft_ids.cdc
├── get_species_coin_balance.cdc
└── get_registered_species.cdc
```

### Enhanced Process Flow
1. **Register Species**: Maps species code to contract address
2. **Mint Fish NFT**: Stores species code in metadata + marks as minted
3. **Mint Species Coins**: Calls WalleyeCoin's `processCatchFromNFT()`
4. **Track Minting**: Prevents double-minting across all species
5. **Retroactive Support**: Handle existing NFTs with batch processing
6. **Status Checking**: Query which NFTs need processing

---

## Anti-Double-Minting System

### How It Works
- **Centralized Tracking**: FishNFT contract tracks all species coin minting
- **Cross-Species Prevention**: Works for all current and future species coins
- **Batch Operations**: Efficient processing of multiple NFTs
- **Race Condition Safe**: Double-checks prevent concurrent minting issues

### Key Functions
```cadence
// Check if species coins have been minted for an NFT
FishNFT.hasSpeciesCoinsBeenMinted(fishNFTId: UInt64): Bool

// Mark an NFT as having species coins minted
FishNFT.markSpeciesCoinsAsMinted(fishNFTId: UInt64)

// Get list of NFTs that haven't been minted
FishNFT.getUnmintedNFTs(nftIds: [UInt64]): [UInt64]

// Get minting status for multiple NFTs
FishNFT.getMintingStatus(nftIds: [UInt64]): {UInt64: Bool}
```

---

## Troubleshooting

### Common Issues

1. **"Species coins already minted"**
   - ✅ **Expected behavior** - the system is preventing double-minting
   - Use status checking script to verify current state

2. **"Fish NFT is not a Walleye"**
   - ✅ **Expected behavior** - WalleyeCoin only processes Walleye species
   - Check NFT species code matches `"SANDER_VITREUS"`

3. **Import errors during development**
   - ✅ **Normal** - contracts must be deployed first
   - Run `flow project deploy` to resolve

4. **"All specified Fish NFTs have already had species coins minted"**
   - ✅ **System working correctly** - no double-minting allowed
   - Check status to see which NFTs are already processed

### Debug Commands

```sh
# Check what NFTs exist
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc --args-json '[{"type":"Address","value":"ACCOUNT_ADDRESS"}]'

# Check which have been minted
flow scripts execute cadence/scripts/check-nft-minting-status.cdc --args-json '[{"type":"Array","value":[{"type":"UInt64","value":"1"}]}]'

# Check species coin balance
flow scripts execute cadence/scripts/get_species_coin_balance.cdc --args-json '[{"type":"Address","value":"ACCOUNT_ADDRESS"},{"type":"String","value":"SANVIT"}]'
```

---

## Notes

- **Use the comprehensive transaction** (`mint_fish_and_species_coins.cdc`) for new Fish NFTs
- **Use retroactive minting** (`retroactive-species-coin-mint.cdc`) for existing Fish NFTs
- **Species codes must match exactly**: `"SANDER_VITREUS"` for Walleye
- **Each species auto-registers** on first use in comprehensive transaction
- **Double-minting is impossible** - the system tracks and prevents it
- Replace `0x179b6b1cb6755e31` with your actual test account address
- **Fresh emulator needed** if you change contract storage fields
- Use [Flowser](https://flowser.dev/) for visual emulator inspection
