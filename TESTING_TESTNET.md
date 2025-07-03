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

# Fund with testnet FLOW (get from faucet)
# Visit: https://testnet-faucet.onflow.org/
```

### Setup Account for DerbyFish
```bash
# Setup WalleyeCoin vault
flow transactions send cadence/transactions/setup_walleye_coin.cdc --network testnet --signer testnet-user

# Setup FishNFT collection  
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --network testnet --signer testnet-user

# Setup BaitCoin vault (if needed)
flow transactions send cadence/transactions/setup_bait_coin.cdc --network testnet --signer testnet-user
```

**Check Setup Success:**
```bash
# Verify account has empty vaults/collections
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc <USER_ADDRESS> --network testnet
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc <USER_ADDRESS> --network testnet
```

---

## 🎣 **Phase 3: Mint Test NFT**

### Mint Walleye NFT to Test Account
```bash
# Replace with your test account address
export TEST_USER=<YOUR_TEST_USER_ADDRESS>

# Mint a test Walleye NFT
flow transactions send cadence/transactions/mint_walleye_nft.cdc \
  $TEST_USER \
  "Northern Pike Bay" \
  46.7791 \
  -92.1065 \
  28.5 \
  "Jig and Minnow" \
  "QmWalleyeBump123" \
  "QmWalleyeHero456" \
  false \
  "" \
  --network testnet \
  --signer testnet-account
```

**Verify Mint Success:**
```bash
# Check NFT was minted
flow scripts execute cadence/scripts/get_fish_nft_ids.cdc $TEST_USER --network testnet

# Get detailed NFT info (assuming ID 1)
flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc $TEST_USER 1 --network testnet
```

---

## 💰 **Phase 4: Token Operations**

### Test WalleyeCoin Rewards
```bash
# Check if user got WalleyeCoin rewards from minting
flow scripts execute cadence/scripts/get_walleye_coin_balance.cdc $TEST_USER --network testnet

# Get detailed balance info
flow scripts execute cadence/scripts/get_walleye_coin_info.cdc $TEST_USER --network testnet
```

### Test Token Transfers (If Applicable)
```bash
# Transfer tokens between accounts (if both have vaults setup)
flow transactions send cadence/transactions/transfer_walleye_coin.cdc \
  <RECIPIENT_ADDRESS> \
  10.0 \
  --network testnet \
  --signer testnet-user
```

---

## 🔄 **Phase 5: Advanced Testing**

### Test Multiple Species (Future)
```bash
# When you have multiple species deployed, test registration
flow scripts execute cadence/scripts/get_registered_species.cdc --network testnet
```

### Test Cross-Account NFT Transfers
```bash
# Transfer NFT between test accounts
flow transactions send cadence/transactions/transfer_fish_nft.cdc \
  <RECIPIENT_ADDRESS> \
  1 \
  --network testnet \
  --signer testnet-user
```

### Test BaitCoin Integration
```bash
# Check BaitCoin balance
flow scripts execute cadence/scripts/get_bait_coin_balance.cdc $TEST_USER --network testnet

# Test FUSD ↔ BaitCoin swaps (if implemented)
# flow transactions send cadence/transactions/swap_fusd_for_bait.cdc 100.0 --network testnet --signer testnet-user
```

---

## 🧪 **Testing Checklist**

### ✅ **Basic Functionality**
- [ ] Contracts deployed and accessible
- [ ] Metadata scripts return complete data
- [ ] Account setup transactions work
- [ ] NFT minting successful
- [ ] Token balances update correctly

### ✅ **User Experience**  
- [ ] New accounts can setup vaults/collections
- [ ] Minting rewards tokens properly
- [ ] Transfers work between accounts
- [ ] Error handling graceful

### ✅ **Data Integrity**
- [ ] NFT metadata complete and accurate
- [ ] Species data matches expectations
- [ ] Token supplies tracked correctly
- [ ] Blockchain state consistent

---

## 🚨 **Common Issues & Solutions**

### **Account Not Setup**
```
Error: Could not borrow vault reference
Solution: Run setup transactions first
```

### **Insufficient Balance**
```
Error: Amount withdrawn must be <= than the balance
Solution: Check balance, get testnet FLOW from faucet
```

### **Contract Not Found**
```
Error: Cannot find contract
Solution: Verify contract address and network flag
```

---

## 🎯 **Next Steps After Testing**

1. **Document Results** - Note any issues or unexpected behavior
2. **Performance Testing** - Test with multiple rapid transactions
3. **Edge Case Testing** - Test invalid inputs, boundary conditions
4. **Multi-User Testing** - Coordinate with multiple test accounts
5. **Gas Optimization** - Monitor transaction costs
6. **Mainnet Preparation** - Plan mainnet deployment strategy

---

## 📱 **Testnet Resources**

- **Flow Testnet Faucet:** https://testnet-faucet.onflow.org/
- **FlowScan Testnet:** https://testnet.flowscan.io/
- **Your Contract:** https://testnet.flowscan.io/account/fdd7b15179ce5eb8
- **Flow CLI Docs:** https://docs.onflow.org/flow-cli/

---

**🎉 Happy Testing on Flow Testnet!**
