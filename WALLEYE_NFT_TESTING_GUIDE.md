# Walleye NFT Testing Guide

This guide walks you through testing Walleye Fish NFT minting on both emulator and testnet.

## Prerequisites

1. Flow CLI installed
2. Contracts deployed (BaitCoin, FishNFT, etc.)
3. Test accounts set up

## Step-by-Step Walleye NFT Testing

### Phase 1: Account Setup

#### 1.1 Set up angler account with FishNFT collection
```bash
# On emulator
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --signer emulator-account --network emulator

# On testnet  
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --signer testnet-account --network testnet
```

#### 1.2 Verify collection setup
```bash
# Check if collection exists
flow scripts execute cadence/scripts/get_fish_ids.cdc 0xf8d6e0586b0a20c7 --network emulator
# Should return: []
```

### Phase 2: Mint Walleye NFTs

#### 2.1 Mint first Walleye NFT (Lake Minnetonka catch)
```bash
# Example Walleye parameters:
flow transactions send cadence/transactions/mint_fish_nft.cdc \
  0xf8d6e0586b0a20c7 \
  "https://example.com/walleye-bump-1.jpg" \
  "https://example.com/walleye-hero-1.jpg" \
  true \
  "https://example.com/walleye-release-1.mp4" \
  "walleye-bump-hash-123" \
  "walleye-hero-hash-456" \
  "walleye-release-hash-789" \
  -93.2650 \
  44.9778 \
  24.5 \
  "Walleye" \
  "Sander vitreus" \
  1699123456 \
  "Jig and minnow" \
  "Lake Minnetonka, MN" \
  --signer emulator-account --network emulator
```

#### 2.2 Mint second Walleye NFT (Mille Lacs Lake catch)
```bash
flow transactions send cadence/transactions/mint_fish_nft.cdc \
  0xf8d6e0586b0a20c7 \
  "https://example.com/walleye-bump-2.jpg" \
  "https://example.com/walleye-hero-2.jpg" \
  false \
  null \
  "walleye-bump-hash-234" \
  "walleye-hero-hash-567" \
  null \
  -93.6632 \
  46.2659 \
  18.75 \
  "Walleye" \
  "Sander vitreus" \
  1699210000 \
  "Trolling with crawler harness" \
  "Mille Lacs Lake, MN" \
  --signer emulator-account --network emulator
```

#### 2.3 Mint trophy Walleye NFT (Lake of the Woods)
```bash
flow transactions send cadence/transactions/mint_fish_nft.cdc \
  0xf8d6e0586b0a20c7 \
  "https://example.com/walleye-bump-3.jpg" \
  "https://example.com/walleye-hero-3.jpg" \
  true \
  "https://example.com/walleye-release-3.mp4" \
  "walleye-bump-hash-345" \
  "walleye-hero-hash-678" \
  "walleye-release-hash-890" \
  -94.8769 \
  48.9951 \
  28.0 \
  "Walleye" \
  "Sander vitreus" \
  1699296400 \
  "Vertical jigging with minnow" \
  "Lake of the Woods, MN" \
  --signer emulator-account --network emulator
```

### Phase 3: Verification & Testing

#### 3.1 Check NFT count
```bash
flow scripts execute cadence/scripts/get_fish_ids.cdc 0xf8d6e0586b0a20c7 --network emulator
# Should return: [0, 1, 2]
```

#### 3.2 Test the comprehensive Walleye analysis script
```bash
flow scripts execute cadence/scripts/test_walleye_nft.cdc 0xf8d6e0586b0a20c7 --network emulator
```

#### 3.3 Check individual NFT metadata
```bash
# Create a script to check specific NFT details:
cat > check_nft_metadata.cdc << 'EOF'
import "FishNFT"
import "NonFungibleToken"

access(all) fun main(address: Address, nftId: UInt64): {String: AnyStruct} {
    let collection = getAccount(address)
        .capabilities.borrow<&{NonFungibleToken.Collection}>(/public/FishNFTCollection)
        ?? panic("Could not borrow collection")
    
    let nft = collection.borrowNFT(id: nftId) as! &FishNFT.NFT
    let metadata = nft.metadata
    
    return {
        "id": nft.id,
        "species": metadata.species,
        "scientific": metadata.scientific,
        "length": metadata.length,
        "location": metadata.location,
        "gear": metadata.gear,
        "hasRelease": metadata.hasRelease,
        "mintedBy": nft.mintedBy.toString(),
        "mintedAt": nft.mintedAt
    }
}
EOF

# Check each Walleye NFT
flow scripts execute check_nft_metadata.cdc 0xf8d6e0586b0a20c7 0 --network emulator
flow scripts execute check_nft_metadata.cdc 0xf8d6e0586b0a20c7 1 --network emulator  
flow scripts execute check_nft_metadata.cdc 0xf8d6e0586b0a20c7 2 --network emulator
```

### Phase 4: Advanced Testing

#### 4.1 Test NFT transfers
```bash
# Set up second account collection first
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --signer test-acct --network emulator

# Transfer Walleye NFT
flow transactions send cadence/transactions/transfer_fish_nft.cdc \
  0x179b6b1cb6755e31 \
  0 \
  --signer emulator-account --network emulator
```

#### 4.2 Test different Walleye scenarios
Create more Walleye NFTs with different characteristics:

**Small Walleye (under slot)**:
- Length: 14.0 inches
- Location: "Small northern lake"
- Gear: "Ultra-light with small jig"

**Keeper Walleye**:
- Length: 19.5 inches
- Location: "Main lake structure" 
- Gear: "Bottom bouncer with spinner"

**Trophy Walleye**:
- Length: 30.0+ inches
- Location: "Deep water trolling"
- Gear: "Deep diving crankbait"

#### 4.3 Test species coin integration (if implemented)
Check if Walleye NFT minting triggers WalleyeCoin minting:
```bash
flow scripts execute cadence/scripts/get_bc_balance.cdc 0xf8d6e0586b0a20c7 --network emulator
# Check if WalleyeCoin balance increases after NFT minting
```

### Phase 5: Testnet Testing

#### 5.1 Switch to testnet
Replace `--network emulator` with `--network testnet` and use testnet addresses:
- Testnet account: `0x5a8151874f113819`

#### 5.2 Follow same steps as emulator
Run through all the same minting and verification steps on testnet to ensure:
- Network compatibility
- Gas fees work correctly
- Real network performance

### Phase 6: Error Testing

#### 6.1 Test invalid parameters
```bash
# Try minting with invalid length (negative)
flow transactions send cadence/transactions/mint_fish_nft.cdc \
  0xf8d6e0586b0a20c7 \
  "https://example.com/walleye-bump.jpg" \
  "https://example.com/walleye-hero.jpg" \
  false \
  null \
  "hash1" \
  "hash2" \
  null \
  -93.0 \
  44.0 \
  -5.0 \
  "Walleye" \
  "Sander vitreus" \
  1699123456 \
  "Jig" \
  "Test Lake" \
  --signer emulator-account --network emulator
# Should fail gracefully
```

#### 6.2 Test without collection setup
Try minting to an account without a collection set up (should fail).

## Expected Results

### Successful Walleye NFT Testing Should Show:

1. **NFT Minting**: 
   - NFTs created with unique IDs
   - Correct Walleye metadata stored
   - Events emitted properly

2. **Metadata Verification**:
   - Species: "Walleye"
   - Scientific: "Sander vitreus" 
   - Length, location, gear stored correctly
   - Photos/hashes preserved

3. **Collection Management**:
   - NFTs appear in angler's collection
   - Transfer functionality works
   - Public access to read NFT data

4. **Integration**:
   - Compatible with existing scripts
   - Works on both emulator and testnet
   - Proper error handling

## Troubleshooting

### Common Issues:

1. **Collection not set up**: Run setup_fish_nft_collection.cdc first
2. **Insufficient gas**: Ensure accounts have enough FLOW tokens
3. **Wrong address format**: Use proper Flow address format (0x...)
4. **Contract not deployed**: Verify contracts are deployed to target network

### Debug Commands:

```bash
# Check account storage
flow accounts get 0xf8d6e0586b0a20c7 --network emulator

# View recent transactions
flow transactions get <transaction-id> --network emulator

# Check contract deployment
flow contracts get FishNFT 0xf8d6e0586b0a20c7 --network emulator
```

## Next Steps

After successful Walleye NFT testing:

1. Test other fish species (LargemouthBass, etc.)
2. Test species coin minting integration
3. Test FishDEX registration
4. Build frontend interface for easier testing
5. Implement automated test suite

---

**🎣 Happy Testing! 🐟**

This guide provides a comprehensive framework for testing your Walleye NFT functionality. Each step builds on the previous ones to ensure your DerbyFish system works correctly. 