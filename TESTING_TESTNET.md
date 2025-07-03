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
flow scripts execute cadence/scripts/get_walleye_coin_all_metadata.cdc --network testnet

# Check contract info
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc fdd7b15179ce5eb8 --network testnet

# Test FishNFT collection (if any NFTs exist)
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc fdd7b15179ce5eb8 --network testnet
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
flow transactions send cadence/transactions/mint_fish_and_species_coins.cdc \
  --args-json '[
    {"type":"Address","value":"10e2159a4b5a5003"},
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

## 💰 **Phase 4: Token Operations**

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

## 🔄 **Phase 5: Advanced Testing**

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

### Test Token Economy Integration
```bash
# Check FUSD balance (should have some from faucet)
flow scripts execute cadence/scripts/get_fusd_balance.cdc $TEST_USER --network testnet

# Test FUSD ↔ BaitCoin swaps (if swap contracts deployed)
# flow transactions send cadence/transactions/swap_fusd_for_baitcoin.cdc 100.0 --network testnet --signer testnet-user

# Check contract FUSD balance
flow scripts execute cadence/scripts/get_contract_fusd_balance.cdc --network testnet
```

### Test Multiple NFT Minting
```bash
# Mint a second NFT to test sequential IDs
flow transactions send cadence/transactions/mint_fish_and_species_coins.cdc \
  --args-json '[
    {"type":"Address","value":"10e2159a4b5a5003"},
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

# Check both NFTs exist
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc $TEST_USER --network testnet
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc $TEST_USER 2 --network testnet
```

---

## 🧪 **Testing Checklist**

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

### ✅ **Token Operations**  
- [ ] WalleyeCoin rewards minted automatically (1.0 SANVIT per NFT)
- [ ] Token balances update correctly after minting
- [ ] Token transfers work between accounts
- [ ] Species coin balance tracking accurate
- [ ] BaitCoin operations functional

### ✅ **System Integration**
- [ ] Species registry tracks all registered species
- [ ] Cross-contract interactions work (NFT ↔ Token)
- [ ] Multiple species can be registered
- [ ] Account overview shows all assets correctly
- [ ] FUSD integration works (if applicable)

### ✅ **Data Integrity**
- [ ] NFT metadata matches input parameters exactly
- [ ] Species data in WalleyeCoin complete and accurate
- [ ] Token supplies tracked correctly across all operations
- [ ] Blockchain state consistent after all operations
- [ ] Events emitted properly for all transactions

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

### **Transaction Arguments Error**
```
Error: invalid argument format / cannot parse argument
Solution: Use exact JSON format from examples:
  - Strings: {"type":"String","value":"example"}
  - Addresses: {"type":"Address","value":"10e2159a4b5a5003"}
  - Numbers: {"type":"UFix64","value":"26.0"}
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

---

## 📋 **Complete Testing Scenarios Summary**

| Phase | Test Type | Key Commands | What It Validates |
|-------|-----------|--------------|-------------------|
| **1** | Contract Verification | `get_walleye_coin_all_metadata.cdc` | Deployment success, metadata integrity |
| **2** | Account Setup | `setup_*_account.cdc` transactions | Account initialization, vault creation |
| **3** | NFT + Token Minting | `mint_fish_and_species_coins.cdc` | Core system functionality, auto-rewards |
| **4** | Token Operations | Balance/transfer scripts | Token economy, cross-account transfers |
| **5** | Advanced Testing | Multi-NFT, registry, overview | System integration, multiple operations |

**Total Test Functions:** 15+ scripts and transactions  
**Coverage:** NFTs, Tokens, Transfers, Registry, Metadata, Account Management

---

## 🚀 **Quick Start Commands**

**New to testing? Start here:**
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
flow transactions send cadence/transactions/mint_fish_and_species_coins.cdc \
  --args-json '[{"type":"Address","value":"10e2159a4b5a5003"},{"type":"String","value":"https://example.com/walleye-bump.jpg"},{"type":"String","value":"https://example.com/walleye-hero.jpg"},{"type":"Bool","value":true},{"type":"Optional","value":{"type":"String","value":"https://example.com/walleye-release.mp4"}},{"type":"String","value":"hash123"},{"type":"String","value":"hash456"},{"type":"Optional","value":{"type":"String","value":"hash789"}},{"type":"Fix64","value":"-93.2650"},{"type":"Fix64","value":"44.9778"},{"type":"UFix64","value":"26.0"},{"type":"String","value":"Walleye"},{"type":"String","value":"Sander vitreus"},{"type":"UFix64","value":"1699123456.0"},{"type":"Optional","value":{"type":"String","value":"Jig and minnow"}},{"type":"Optional","value":{"type":"String","value":"Lake Minnetonka, MN"}},{"type":"String","value":"SANDER_VITREUS"}]' \
  --network testnet --signer testnet-account

# 6. Verify success
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc $TEST_USER 1 --network testnet
flow scripts execute cadence/scripts/get_species_coin_balance.cdc $TEST_USER "SANVIT" --network testnet
```

---

## 📱 **Testnet Resources**

- **Flow Testnet Faucet:** https://testnet-faucet.onflow.org/
- **FlowScan Testnet:** https://testnet.flowscan.io/
- **Your Contract:** https://testnet.flowscan.io/account/fdd7b15179ce5eb8
- **Flow CLI Docs:** https://docs.onflow.org/flow-cli/

---

**🎉 Happy Testing on Flow Testnet!**
