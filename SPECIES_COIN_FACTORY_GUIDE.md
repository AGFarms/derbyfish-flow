# Species Coin Factory Guide

## Overview

The Species Coin Factory is a smart contract system that creates and manages individual fungible tokens for each fish species in the DerbyFish ecosystem. This system enables the core tokenomics described in your README where each verified fish catch mints exactly one Species Coin for that particular species.

## Architecture

### Core Contracts

1. **SpeciesCoinFactory.cdc** - Main factory contract that:
   - Maintains a registry of all fish species
   - Creates species coins when new species are caught
   - Tracks metadata for each species (first catch, total catches, etc.)
   - Manages admin permissions

2. **SpeciesCoin.cdc** - Template contract for individual species tokens:
   - Implements Flow's FungibleToken standard
   - Contains species-specific metadata (name, scientific name, image)
   - Supports standard token operations (mint, transfer, burn)

3. **BaitCoin.cdc** - The stable USDC-backed currency:
   - 1:1 peg with USDC
   - Base currency for all ecosystem transactions
   - Handles minting/burning with USDC backing

## How It Works

### 1. Species Registration Flow

When a fish is caught and goes through your BHRV (Bump, Hero, Release, Validate) process:

```cadence
// Check if species exists
if (!SpeciesCoinFactory.isSpeciesRegistered(speciesCode: "BASS_LM")) {
    // This is a new species - register it
    adminRef.mintSpeciesCoinForCatch(
        speciesCode: "BASS_LM",
        speciesName: "Largemouth Bass",
        speciesScientificName: "Micropterus salmoides",
        recipient: fisherAddress,
        speciesImageURL: "https://derbyfish.com/images/bass_lm.png"
    )
    // Event emitted: NewSpeciesDetected
    // Event emitted: SpeciesRegistered  
    // Event emitted: SpeciesCoinMinted
} else {
    // Species already exists - just mint the coin
    adminRef.mintSpeciesCoinForCatch(
        speciesCode: "BASS_LM",
        speciesName: "Largemouth Bass", 
        speciesScientificName: "Micropterus salmoides",
        recipient: fisherAddress,
        speciesImageURL: null
    )
    // Event emitted: SpeciesCoinMinted
}
```

### 2. Species Coin Properties

Each species coin has these characteristics:

- **Organic Scarcity**: Supply = total verified catches of that species
- **Unique Identity**: Each species has its own token contract instance
- **Rich Metadata**: Name, scientific name, image, first catch info
- **Standard Interface**: Follows Flow FungibleToken standard

### 3. Integration Points

The factory integrates with your existing systems:

```cadence
// After BHRV validation succeeds:
let success = SpeciesCoinFactory.mintSpeciesCoinForCatch(
    speciesCode: fishData.speciesCode,
    speciesName: fishData.commonName,
    speciesScientificName: fishData.scientificName,
    recipient: fisherAddress,
    speciesImageURL: fishData.imageURL
)

// Simultaneously mint FishNFT with same catch data
let fishNFT <- FishNFT.mintFishNFT(
    species: fishData.speciesCode,
    catchData: catchMetadata,
    recipient: fisherAddress
)
```

## Usage Examples

### Pre-register Common Species

You can seed the system with known fish species before any catches:

```bash
flow transactions send cadence/transactions/pre_register_species.cdc \
  --arg String:"BASS_LM" \
  --arg String:"Largemouth Bass" \
  --arg String:"Micropterus salmoides" \
  --arg String:"https://derbyfish.com/images/bass_lm.png" \
  --signer admin
```

### Query Species Information

```bash
# Get info about a specific species
flow scripts execute cadence/scripts/get_species_info.cdc --arg String:"BASS_LM"

# Get all registered species
flow scripts execute cadence/scripts/get_all_species.cdc
```

### Mint Species Coin for Catch

```bash
flow transactions send cadence/transactions/create_species_coin_for_catch.cdc \
  --arg String:"BASS_LM" \
  --arg String:"Largemouth Bass" \
  --arg String:"Micropterus salmoides" \
  --arg Address:0x1234567890abcdef \
  --arg String:"https://derbyfish.com/images/bass_lm.png" \
  --signer admin
```

## Economic Model Integration

### Species Coin ↔ Bait Coin Exchange

The factory sets the foundation for your economic model:

1. **Direct Sales**: DerbyFish buys Species Coins at fixed BAIT rates
2. **AMM Pools**: When enough supply exists, create BAIT/Species trading pairs  
3. **Price Discovery**: Market forces determine species coin values

### Implementation Considerations

1. **Minter Permissions**: Only verified catches should mint Species Coins
2. **Species Codes**: Use consistent, unique identifiers (e.g., "BASS_LM", "TROUT_RB")
3. **Metadata Standards**: Standardize image URLs, naming conventions
4. **Catch Verification**: Integrate with your BHRV validation system
5. **Event Monitoring**: Listen for SpeciesCoinMinted events to update UI

## Security Features

- **Admin-Only Minting**: Only authorized contracts can mint Species Coins
- **Species Registry**: Prevents duplicate species with different data
- **Immutable Metadata**: Species information cannot be changed after registration
- **Event Logging**: All species registration and minting events are recorded

## Next Steps

1. **Deploy Contracts**: Deploy SpeciesCoinFactory and SpeciesCoin to testnet
2. **Integration**: Connect to your BHRV validation system
3. **Species Database**: Pre-register common fish species
4. **UI Integration**: Display species coins in user wallets
5. **Trading System**: Implement Bait ↔ Species coin exchange
6. **AMM Integration**: Build automated market makers for popular species

## Advanced Features

### Future Enhancements

1. **Seasonal Multipliers**: Bonus tokens for catches during certain seasons
2. **Rarity Bonuses**: Extra tokens for rare species
3. **Location Tracking**: Species coins tied to catch locations
4. **Tournament Integration**: Special tournament-specific species coins
5. **Governance**: Species coin holders vote on ecosystem decisions

This factory system provides the foundation for a rich, species-specific token economy that grows organically with real fishing activity! 