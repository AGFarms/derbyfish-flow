# DerbyFish Testnet Testing Guide

## 🌊 **Testnet Deployment Overview**

**Contract Address:** `fdd7b15179ce5eb8`  
**Deployed Contracts:** WalleyeCoin, FishNFT, BaitCoin  
**Network:** Flow Testnet  
**Explorer:** https://testnet.flowscan.io/account/fdd7b15179ce5eb8

---

## 🎯 **Phase 1: Basic Contract Verification**

### Test Contract Deployment
```bash
# Verify WalleyeCoin metadata
flow scripts execute flow/cadence/scripts/get_walleye_coin_all_metadata.cdc --network testnet

# Check contract info
flow scripts execute flow/cadence/scripts/get_walleye_coin_info.cdc fdd7b15179ce5eb8 --network testnet

# Test FishNFT collection (if any NFTs exist)
flow scripts execute flow/cadence/scripts/get_fish_nft_ids.cdc fdd7b15179ce5eb8 --network testnet
```

**Expected Results:**
- ✅ WalleyeCoin metadata loads with all species data
- ✅ Contract info shows proper setup
- ✅ NFT collection returns empty or existing IDs

---

## 🆕 **Phase 2: Create Test User Account**

### Create Fresh Testnet Account
```bash
# Generate new testnet account
flow accounts create

# Create account with name "testnet-user" on testnet network
flow accounts create --network testnet --name testnet-user

# Fund with testnet FLOW (get from faucet)
# Visit: https://testnet-faucet.onflow.org/
```

### Setup Account for DerbyFish
```bash
# Setup WalleyeCoin vault
flow transactions send cadence/transactions/setup_walleye_coin_account.cdc --network testnet --signer testnet-user

# Setup FishNFT collection  
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --network testnet --signer testnet-user

# Setup BaitCoin vault (if needed)
flow transactions send cadence/transactions/setup_bc_account.cdc --network testnet --signer testnet-user
```

**Check Setup Success:**
```bash
# Verify account has empty vaults/collections
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc <USER_ADDRESS> --network testnet
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc <USER_ADDRESS> --network testnet
```

---

## 🎣 **Phase 3: Mint Test NFT**

### Set Test User Address
```bash
# Use your testnet-user address
export TEST_USER=10e2159a4b5a5003
```

### Comprehensive Fish NFT + Species Coin Minting
```bash
# Recommended: All-in-One Transaction (handles everything)
flow transactions send cadence/transactions/mint_fish_and_species_coins_testnet.cdc \
  --args-json '[
    {"type":"Address","value":"0x7149e49f728573b0"},
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
  --network testnet \
  --signer testnet-account
```

**What this accomplishes:**
- ✅ Auto-registers "SANDER_VITREUS" species if needed
- ✅ Mints Fish NFT with complete metadata
- ✅ Mints 1.0 SANVIT species coins automatically  
- ✅ Deposits both NFT and coins to user account
- ✅ Marks NFT as having species coins minted (prevents double-minting)

**Verify Mint Success:**
```bash
# Check NFT was minted
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc $TEST_USER --network testnet

# Get detailed NFT info (assuming ID 1)
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc $TEST_USER 1 --network testnet

# Check species registration worked
flow scripts execute cadence/scripts/get_registered_species.cdc --network testnet
```

---

## 🔄 **Phase 4: NEW - Retroactive Species Coin Minting**

**Use Case**: Mint species coins for Fish NFTs that were created before the species coin system was implemented, or when automatic minting failed.

### Check Minting Status First

```bash
# Check which NFTs have/haven't been minted (replace with actual NFT IDs)
flow scripts execute cadence/scripts/check-nft-minting-status.cdc \
  --args-json '[{"type":"Array","value":[{"type":"UInt64","value":"1"},{"type":"UInt64","value":"2"},{"type":"UInt64","value":"3"}]}]' \
  --network testnet
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

```bash
# Process multiple existing NFTs for retroactive minting
flow transactions send cadence/transactions/retroactive-species-coin-mint.cdc \
  --args-json '[
    {"type":"Address","value":"0x10e2159a4b5a5003"},
    {"type":"Array","value":[
      {"type":"UInt64","value":"2"},
      {"type":"UInt64","value":"3"},
      {"type":"UInt64","value":"4"}
    ]}
  ]' \
  --network testnet \
  --signer testnet-account
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

## 💰 **Phase 5: Token Operations**

### Test WalleyeCoin Rewards
```bash
# Check if user got WalleyeCoin rewards from minting
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc $TEST_USER --network testnet

# Get detailed balance info  
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc $TEST_USER --network testnet

# Get complete WalleyeCoin metadata profile
flow scripts execute cadence/scripts/get_walleye_coin_all_metadata.cdc --network testnet
```

### Test Species Coin Balance
```bash
# Check SANVIT (Walleye) species coin balance
flow scripts execute cadence/scripts/get_species_coin_balance.cdc $TEST_USER "SANVIT" --network testnet
```

### Test Token Transfers
```bash
# Transfer WalleyeCoin between accounts (if both have vaults setup)
flow transactions send cadence/transactions/transfer_walleye_coin.cdc \
  fdd7b15179ce5eb8 \
  0.5 \
  --network testnet \
  --signer testnet-user

# Verify transfer worked
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc $TEST_USER --network testnet
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc fdd7b15179ce5eb8 --network testnet
```

### Test BaitCoin Operations
```bash
# Check BaitCoin balance
flow scripts execute cadence/scripts/get_bc_balance.cdc $TEST_USER --network testnet

# Transfer BaitCoin (if available)
flow transactions send cadence/transactions/transfer_baitcoin.cdc \
  fdd7b15179ce5eb8 \
  10.0 \
  --network testnet \
  --signer testnet-user
```

---

## 🔄 **Phase 6: Advanced Testing**

### Test Species Registry
```bash
# Check all registered species
flow scripts execute cadence/scripts/get_registered_species.cdc --network testnet

# Register additional species manually (if needed)
flow transactions send cadence/transactions/register_species.cdc "EXAMPLE_FISH" fdd7b15179ce5eb8 \
  --network testnet \
  --signer testnet-account
```

### Test Cross-Account NFT Transfers
```bash
# Transfer NFT between test accounts (NFT ID 1 to contract account)
flow transactions send cadence/transactions/transfer_fish_nft.cdc \
  fdd7b15179ce5eb8 \
  1 \
  --network testnet \
  --signer testnet-user

# Verify transfer
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc $TEST_USER --network testnet
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc fdd7b15179ce5eb8 --network testnet
```

### Test Complete Account Overview
```bash
# Get comprehensive account status
echo "=== FISH NFTs ==="
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc $TEST_USER --network testnet

echo "=== WALLEYE COINS ==="
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc $TEST_USER --network testnet

echo "=== SPECIES COINS ==="
flow scripts execute cadence/scripts/get_species_coin_balance.cdc $TEST_USER "SANVIT" --network testnet

echo "=== BAITCOIN ==="
flow scripts execute cadence/scripts/get_bc_balance.cdc $TEST_USER --network testnet

echo "=== FUSD ==="
flow scripts execute cadence/scripts/get_fusd_balance.cdc $TEST_USER --network testnet
```

### NEW: Test Anti-Double-Minting System
```bash
# Check minting status for multiple NFTs
flow scripts execute cadence/scripts/check-nft-minting-status.cdc \
  --args-json '[{"type":"Array","value":[{"type":"UInt64","value":"1"},{"type":"UInt64","value":"2"},{"type":"UInt64","value":"3"}]}]' \
  --network testnet

# Get all minted NFT IDs globally
flow scripts execute cadence/scripts/get_all_minted_nft_ids.cdc --network testnet

# Try to mint species coins for already-minted NFT (should be prevented)
flow transactions send cadence/transactions/retroactive-species-coin-mint.cdc \
  --args-json '[
    {"type":"Address","value":"0x10e2159a4b5a5003"},
    {"type":"Array","value":[{"type":"UInt64","value":"1"}]}
  ]' \
  --network testnet \
  --signer testnet-account
# Expected: "All specified Fish NFTs have already had species coins minted - nothing to do"
```

### Test Token Economy Integration
```bash
# Check FUSD balance (should have some from faucet)
flow scripts execute cadence/scripts/get_fusd_balance.cdc $TEST_USER --network testnet

# Test FUSD ↔ BaitCoin swaps (if swap contracts deployed)
# flow transactions send cadence/transactions/swap_fusd_for_baitcoin.cdc 100.0 --network testnet --signer testnet-user

# Check contract FUSD balance
flow scripts execute cadence/scripts/get_contract_fusd_balance.cdc --network testnet
```

### Test Multiple NFT Minting with Tracking
```bash
# Mint a second NFT to test sequential IDs and tracking
flow transactions send cadence/transactions/mint_fish_and_species_coins_testnet.cdc \
  --args-json '[
    {"type":"Address","value":"0x10e2159a4b5a5003"},
    {"type":"String","value":"https://example.com/walleye2-bump.jpg"},
    {"type":"String","value":"https://example.com/walleye2-hero.jpg"},
    {"type":"Bool","value":false},
    {"type":"Optional","value":null},
    {"type":"String","value":"hash124"},
    {"type":"String","value":"hash457"},
    {"type":"Optional","value":null},
    {"type":"Fix64","value":"-94.1234"},
    {"type":"Fix64","value":"45.5678"},
    {"type":"UFix64","value":"24.0"},
    {"type":"String","value":"Walleye"},
    {"type":"String","value":"Sander vitreus"},
    {"type":"UFix64","value":"1699123556.0"},
    {"type":"Optional","value":{"type":"String","value":"Trolling with crankbait"}},
    {"type":"Optional","value":{"type":"String","value":"Mille Lacs Lake, MN"}},
    {"type":"String","value":"SANDER_VITREUS"}
  ]' \
  --network testnet \
  --signer testnet-account

# Check both NFTs exist and are properly tracked
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc $TEST_USER --network testnet
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc $TEST_USER 2 --network testnet

# Verify both NFTs show as minted in tracking system
flow scripts execute cadence/scripts/check-nft-minting-status.cdc \
  --args-json '[{"type":"Array","value":[{"type":"UInt64","value":"1"},{"type":"UInt64","value":"2"}]}]' \
  --network testnet
```

---

## 🧪 **Enhanced Testing Checklist**

### ✅ **Contract Deployment**
- [ ] Contracts deployed and accessible at `fdd7b15179ce5eb8`
- [ ] WalleyeCoin metadata returns complete species profile
- [ ] Contract info scripts work without errors
- [ ] Explorer shows contracts properly deployed

### ✅ **Account Setup**
- [ ] New testnet accounts can be created
- [ ] Setup transactions work (vaults/collections)
- [ ] Account funding from faucet successful
- [ ] Empty vaults/collections show correct initial state

### ✅ **NFT Operations**
- [ ] Comprehensive minting transaction works
- [ ] NFT metadata complete and accurate (species code, location, photos)
- [ ] Sequential NFT IDs work properly
- [ ] NFT transfers between accounts successful
- [ ] Species auto-registration on first mint
- [ ] **NEW**: NFT minting tracking works correctly

### ✅ **Token Operations**  
- [ ] WalleyeCoin rewards minted automatically (1.0 SANVIT per NFT)
- [ ] Token balances update correctly after minting
- [ ] Token transfers work between accounts
- [ ] Species coin balance tracking accurate
- [ ] BaitCoin operations functional
- [ ] **NEW**: Double-minting prevention works

### ✅ **NEW: Anti-Double-Minting System**
- [ ] Status checking scripts return accurate data
- [ ] Retroactive minting processes only unminted NFTs
- [ ] Already-minted NFTs are properly skipped
- [ ] Batch operations handle mixed minted/unminted NFTs
- [ ] Race condition protection prevents concurrent double-minting
- [ ] Species validation works (only Walleye → WalleyeCoin)

### ✅ **NEW: Retroactive Minting**
- [ ] Can identify which NFTs need retroactive processing
- [ ] Batch processing handles multiple NFTs efficiently
- [ ] Detailed logging shows exactly what was processed
- [ ] Final status report accurate for all requested NFTs
- [ ] Cross-species validation prevents wrong coin types

### ✅ **System Integration**
- [ ] Species registry tracks all registered species
- [ ] Cross-contract interactions work (NFT ↔ Token)
- [ ] Multiple species can be registered
- [ ] Account overview shows all assets correctly
- [ ] FUSD integration works (if applicable)
- [ ] **NEW**: Tracking system integrates across all transactions

### ✅ **Data Integrity**
- [ ] NFT metadata matches input parameters exactly
- [ ] Species data in WalleyeCoin complete and accurate
- [ ] Token supplies tracked correctly across all operations
- [ ] Blockchain state consistent after all operations
- [ ] Events emitted properly for all transactions
- [ ] **NEW**: Minting status persistent and accurate

---

## 🚨 **Common Issues & Solutions**

### **Account Not Setup**
```
Error: Could not borrow FishNFT collection / Could not borrow vault reference
Solution: Run setup transactions first:
  flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --network testnet --signer testnet-user
  flow transactions send cadence/transactions/setup_walleye_coin_account.cdc --network testnet --signer testnet-user
```

### **Insufficient FLOW Balance**
```
Error: insufficient balance / Amount withdrawn must be <= than the balance  
Solution: Get testnet FLOW from faucet:
  Visit: https://testnet-faucet.onflow.org/
  Enter your testnet address: 10e2159a4b5a5003
```

### **Contract Not Found**
```
Error: Cannot find contract / Contract does not exist
Solution: Verify contract address and network flag:
  - Contract Address: fdd7b15179ce5eb8
  - Always use: --network testnet
  - Check deployment: https://testnet.flowscan.io/account/fdd7b15179ce5eb8
```

### **NFT Not Found**
```
Error: NFT with ID X not found in collection
Solution: Check available NFT IDs first:
  flow scripts execute cadence/scripts/get_fish_nft_ids.cdc 10e2159a4b5a5003 --network testnet
```

### **Species Not Registered**
```
Error: Species validation failed / Species not found
Solution: Check registered species and use correct code:
  flow scripts execute cadence/scripts/get_registered_species.cdc --network testnet
  Use "SANDER_VITREUS" for Walleye
```

### **NEW: "Species coins already minted"**
```
Error/Log: "All specified Fish NFTs have already had species coins minted - nothing to do"
Solution: This is EXPECTED behavior - the anti-double-minting system is working!
  - Check status: flow scripts execute cadence/scripts/check-nft-minting-status.cdc
  - Verify which NFTs are already processed vs need processing
```

### **NEW: "Fish NFT is not a Walleye"**
```
Log: "Fish NFT #X is not a Walleye (OTHER_SPECIES) - skipping"
Solution: This is EXPECTED behavior - WalleyeCoin only processes Walleye NFTs
  - Verify NFT species code: should be "SANDER_VITREUS" for WalleyeCoin
  - Other species will need their respective species coin contracts
```

### **Transaction Arguments Error**
```
Error: invalid argument format / cannot parse argument
Solution: Use exact JSON format from examples:
  - Strings: {"type":"String","value":"example"}
  - Addresses: {"type":"Address","value":"10e2159a4b5a5003"}
  - Numbers: {"type":"UFix64","value":"26.0"}
  - Arrays: {"type":"Array","value":[{"type":"UInt64","value":"1"}]}
  - Optional: {"type":"Optional","value":null} or {"type":"Optional","value":{"type":"String","value":"example"}}
```

### **Network Connection Issues**
```
Error: connection refused / network timeout
Solution: Check network configuration:
  - Verify testnet endpoint: access.devnet.nodes.onflow.org:9000
  - Check internet connection
  - Try switching to different Flow Access Node
```

### **Private Key Issues**
```
Error: could not read private key / invalid key format
Solution: Check key file and permissions:
  - Verify testnet-user.pkey exists and is readable
  - Check flow.json account configuration
  - Regenerate account if necessary: flow accounts create --network testnet
```

---

## 🎯 **Next Steps After Testing**

1. **Document Results** - Note any issues, unexpected behavior, transaction costs
2. **Performance Testing** - Test with multiple rapid transactions, stress test minting
3. **Edge Case Testing** - Test invalid inputs, boundary conditions, error handling
4. **Multi-User Testing** - Create multiple test accounts, test concurrent operations
5. **Gas Optimization** - Monitor transaction costs, optimize for mainnet deployment
6. **UI Integration** - Test all scripts/transactions from frontend application
7. **Security Audit** - Review contract permissions, access controls, potential vulnerabilities
8. **Mainnet Preparation** - Plan mainnet deployment strategy, user onboarding flow
9. **NEW: Anti-Double-Minting Testing** - Stress test tracking system with concurrent transactions
10. **NEW: Retroactive Processing** - Test with large batches of existing NFTs

---

## 📋 **Complete Testing Scenarios Summary**

| Phase | Test Type | Key Commands | What It Validates |
|-------|-----------|--------------|-------------------|
| **1** | Contract Verification | `get_walleye_coin_all_metadata.cdc` | Deployment success, metadata integrity |
| **2** | Account Setup | `setup_*_account.cdc` transactions | Account initialization, vault creation |
| **3** | NFT + Token Minting | `mint_fish_and_species_coins_testnet.cdc` | Core system functionality, auto-rewards |
| **4** | **NEW: Retroactive Minting** | `retroactive-species-coin-mint.cdc` | Batch processing, anti-double-minting |
| **5** | Token Operations | Balance/transfer scripts | Token economy, cross-account transfers |
| **6** | Advanced Testing | Multi-NFT, registry, tracking | System integration, multiple operations |

**Total Test Functions:** 20+ scripts and transactions  
**Coverage:** NFTs, Tokens, Transfers, Registry, Metadata, Account Management, **Anti-Double-Minting**

---

## 🆕 **New Architecture Overview**

### Enhanced Testnet Design with Tracking
```
FishNFT Contract (fdd7b15179ce5eb8)
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
├── mint_fish_and_species_coins_testnet.cdc (recommended for new NFTs)
├── retroactive-species-coin-mint.cdc (NEW - for existing NFTs)
├── mint_fish_nft_with_species.cdc (NFT only)
└── mint_species_coin_for_catch.cdc (coins only)

Script Layer
├── check-nft-minting-status.cdc (NEW - check tracking status)
├── get_fish_nft_ids.cdc
├── get_species_coin_balance.cdc
├── get_registered_species.cdc
└── get_all_minted_nft_ids.cdc (NEW - global tracking view)
```

### Enhanced Process Flow
1. **Register Species**: Maps species code to contract address
2. **Mint Fish NFT**: Stores species code in metadata + marks as minted
3. **Mint Species Coins**: Calls WalleyeCoin's `processCatchFromNFT()`
4. **Track Minting**: Prevents double-minting across all species
5. **Retroactive Support**: Handle existing NFTs with batch processing
6. **Status Checking**: Query which NFTs need processing

---

## 🚀 **Quick Start Commands for Testnet**

**New to testnet testing? Start here:**
```bash
# 1. Verify deployment
flow scripts execute cadence/scripts/get_walleye_coin_all_metadata.cdc --network testnet

# 2. Set your test user
export TEST_USER=10e2159a4b5a5003

# 3. Check account status
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc $TEST_USER --network testnet
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc $TEST_USER --network testnet

# 4. If setup needed:
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --network testnet --signer testnet-user
flow transactions send cadence/transactions/setup_walleye_coin_account.cdc --network testnet --signer testnet-user

# 5. Mint your first NFT + tokens
flow transactions send cadence/transactions/mint_fish_and_species_coins_testnet.cdc \
  --args-json '[{"type":"Address","value":"0x10e2159a4b5a5003"},{"type":"String","value":"https://example.com/walleye-bump.jpg"},{"type":"String","value":"https://example.com/walleye-hero.jpg"},{"type":"Bool","value":true},{"type":"Optional","value":{"type":"String","value":"https://example.com/walleye-release.mp4"}},{"type":"String","value":"hash123"},{"type":"String","value":"hash456"},{"type":"Optional","value":{"type":"String","value":"hash789"}},{"type":"Fix64","value":"-93.2650"},{"type":"Fix64","value":"44.9778"},{"type":"UFix64","value":"26.0"},{"type":"String","value":"Walleye"},{"type":"String","value":"Sander vitreus"},{"type":"UFix64","value":"1699123456.0"},{"type":"Optional","value":{"type":"String","value":"Jig and minnow"}},{"type":"Optional","value":{"type":"String","value":"Lake Minnetonka, MN"}},{"type":"String","value":"SANDER_VITREUS"}]' \
  --network testnet --signer testnet-account

# 6. Verify success and tracking
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc $TEST_USER 1 --network testnet
flow scripts execute cadence/scripts/get_species_coin_balance.cdc $TEST_USER "SANVIT" --network testnet
flow scripts execute cadence/scripts/check-nft-minting-status.cdc --args-json '[{"type":"Array","value":[{"type":"UInt64","value":"1"}]}]' --network testnet

# 7. NEW: Test retroactive minting (will show "already minted" - expected!)
flow transactions send cadence/transactions/retroactive-species-coin-mint.cdc \
  --args-json '[{"type":"Address","value":"0x10e2159a4b5a5003"},{"type":"Array","value":[{"type":"UInt64","value":"1"}]}]' \
  --network testnet --signer testnet-account
```

---

## 📱 **Testnet Resources**

- **Flow Testnet Faucet:** https://testnet-faucet.onflow.org/
- **FlowScan Testnet:** https://testnet.flowscan.io/
- **Your Contract:** https://testnet.flowscan.io/account/fdd7b15179ce5eb8
- **Flow CLI Docs:** https://docs.onflow.org/flow-cli/

---

**🎉 Happy Testing with Enhanced Anti-Double-Minting on Flow Testnet!**
