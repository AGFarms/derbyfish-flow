# Flow CLI Testing & Deployment Guide

This guide walks you through a typical local development workflow for DerbyFish using the Flow CLI. It covers starting the emulator, deploying contracts, creating a test account, setting up NFT and species coin vaults, minting Fish NFTs with automatic species coin minting, and querying balances.

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

## 7. Check Results

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

---

## Expected Results

After running the comprehensive transaction (Step 6):

1. **Fish NFT**: Minted with `speciesCode: "SANDER_VITREUS"` stored in metadata
2. **Species Coins**: 1.0 SANVIT automatically minted to test account  
3. **Species Registry**: "SANDER_VITREUS" registered to WalleyeCoin contract address
4. **Events**: `FishMinted`, `SpeciesRegistered`, and WalleyeCoin minting events

**Expected Balances:**
- Fish NFTs: `[1]` (or next sequential ID)
- SANVIT coins: `1.00000000`

---

## Architecture Overview

### Simplified Design
```
FishNFT Contract
├── Species Registry: {String: Address}
├── registerSpecies(code, address)
├── getSpeciesAddress(code) -> Address?
└── mintNFTWithSpeciesValidation(...)

Transaction Layer  
├── mint_fish_and_species_coins.cdc (recommended)
├── mint_fish_nft_with_species.cdc (NFT only)
└── mint_species_coin_for_catch.cdc (coins only)
```

### Process Flow
1. **Register Species**: Maps species code to contract address
2. **Mint Fish NFT**: Stores species code in metadata
3. **Mint Species Coins**: Calls WalleyeCoin's `processCatchFromNFT()`
4. **Deposit Both**: NFT and coins go to angler's account

---

## Notes

- **Use the comprehensive transaction** (`mint_fish_and_species_coins.cdc`) for best results
- **Species codes must match exactly**: `"SANDER_VITREUS"` for Walleye
- **Each species auto-registers** on first use in comprehensive transaction
- Replace `0x179b6b1cb6755e31` with your actual test account address
- **Fresh emulator needed** if you change contract storage fields
- Use [Flowser](https://flowser.dev/) for visual emulator inspection
