# DerbyFish FishNFT Contract

This directory contains the FishNFT contract and related transactions for the DerbyFish platform.

## Overview

The FishNFT contract implements the Flow NonFungibleToken standard and is designed to be minted by a central authority (DerbyFish platform) after fish submission verification. Each NFT contains comprehensive metadata about the catch including photos, GPS coordinates, species information, and more.

## Contract Features

- **FishMinted Event**: Emitted when a new NFT is minted, including recipient address and key metadata
- **Comprehensive Metadata**: Stores all catch information including:
  - Photo URLs (bump shot, hero shot, release video)
  - File hashes for verification
  - GPS coordinates (latitude/longitude)
  - Fish details (species, scientific name, length)
  - Timestamp and optional gear/location info
- **Metadata Views**: Implements Flow MetadataViews for marketplace compatibility
- **Centralized Minting**: Only authorized minters can create NFTs

## Files

### Contracts
- `FishNFT.cdc` - Main contract implementing the NFT standard

### Transactions
- `deploy_fish_nft.cdc` - Deploy the FishNFT contract
- `setup_fish_nft_collection.cdc` - Initialize user's NFT collection
- `mint_fish_nft.cdc` - Mint a new FishNFT (central authority only)

## Deployment Instructions

1. **Deploy the Contract**:
   ```bash
   flow transactions send cadence/transactions/deploy_fish_nft.cdc --signer emulator-account
   ```

2. **Setup User Collections** (for each user):
   ```bash
   flow transactions send cadence/transactions/setup_fish_nft_collection.cdc --signer test_angler
   ```

## Minting Process

The central authority (DerbyFish platform) can mint NFTs using the `mint_fish_nft.cdc` transaction with the following parameters:

- `recipient`: Address of the angler receiving the NFT
- `bumpShotUrl`: URL to the bump shot photo
- `heroShotUrl`: URL to the hero shot photo
- `hasRelease`: Boolean indicating if fish was released
- `releaseVideoUrl`: Optional URL to release video
- `bumpHash`: Hash of bump shot file
- `heroHash`: Hash of hero shot file
- `releaseHash`: Optional hash of release video
- `longitude`: GPS longitude
- `latitude`: GPS latitude
- `length`: Fish length in inches
- `species`: Common species name
- `scientific`: Scientific species name
- `timestamp`: Catch timestamp
- `gear`: Optional gear used
- `location`: Optional location name

## Example Usage

```bash
# Mint a fish NFT for a verified catch
flow transactions send cadence/transactions/mint_fish_nft.cdc \
  --arg Address:179b6b1cb6755e31 \
  --arg String:"https://derbyfish.com/photos/bump_123.jpg" \
  --arg String:"https://derbyfish.com/photos/hero_123.jpg" \
  --arg Bool:true \
  --arg String:"https://derbyfish.com/videos/release_123.mp4" \
  --arg String:"abc123def456" \
  --arg String:"def456ghi789" \
  --arg String:"ghi789jkl012" \
  --arg Fix64:-87.6298 \
  --arg Fix64:41.8781 \
  --arg UFix64:24.5 \
  --arg String:"Largemouth Bass" \
  --arg String:"Micropterus salmoides" \
  --arg UFix64:1640995200.0 \
  --arg String:"Spinnerbait" \
  --arg String:"Lake Michigan" \
  --signer emulator-account
```

## Event Monitoring

The `FishMinted` event is emitted for each minted NFT and can be monitored for:
- Off-chain indexing
- UI updates
- Integration with other DerbyFish systems
- Analytics and reporting

## Security Considerations

- Only authorized accounts with the NFTMinter resource can mint NFTs
- All metadata is immutable once minted
- File hashes provide verification of photo authenticity
- GPS coordinates are stored on-chain for permanent record 