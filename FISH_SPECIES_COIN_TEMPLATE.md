# Fish Species Coin Contract Template

## Overview

This document defines the standardized template for creating individual fungible token contracts for each fish species in the DerbyFish ecosystem. Each species gets its own unique coin contract following these standards to ensure consistency and prevent conflicts.

## Metadata Standards

### Naming Convention

**Species Code Format**: `{GENUS}_{SPECIES}_{VARIANT?}`
- Use scientific genus and species names
- All uppercase with underscores
- Add variant suffix for subspecies if needed
- Maximum 20 characters

**Examples**:
- `MICROPTERUS_SALMOIDES` (Largemouth Bass)
- `SALMO_TRUTTA` (Brown Trout)
- `ESOX_LUCIUS` (Northern Pike)
- `PERCA_FLAVESCENS` (Yellow Perch)

### Ticker Symbol Standards

**Format**: `{GENUS_ABBREV}{SPECIES_ABBREV}`
- First 2-3 letters of genus + first 2-3 letters of species
- Maximum 6 characters
- All uppercase
- Must be globally unique

**Examples**:
- `MICSAL` (Micropterus salmoides - Largemouth Bass)
- `SALTR` (Salmo trutta - Brown Trout) 
- `ESLUC` (Esox lucius - Northern Pike)
- `PERFLA` (Perca flavescens - Yellow Perch)

### Display Name Standards

**Format**: `{Common Name} Coin`
- Use widely recognized common name
- Add "Coin" suffix
- Title case

**Examples**:
- "Largemouth Bass Coin"
- "Brown Trout Coin"
- "Northern Pike Coin"
- "Yellow Perch Coin"

## Contract Template Structure

```cadence
import "FungibleToken"
import "MetadataViews"
import "FungibleTokenMetadataViews"

access(all) contract {SPECIES_CODE}Coin: FungibleToken {

    // Events
    access(all) event TokensMinted(amount: UFix64, to: Address?)
    access(all) event TokensBurned(amount: UFix64, from: Address?)
    access(all) event CatchVerified(fishId: UInt64, angler: Address, amount: UFix64)

    // Total supply
    access(all) var totalSupply: UFix64

    // Species metadata - IMMUTABLE after initialization
    access(all) let speciesMetadata: SpeciesMetadata

    // Storage paths
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    // Species metadata structure
    access(all) struct SpeciesMetadata {
        access(all) let speciesCode: String        // e.g., "MICROPTERUS_SALMOIDES"
        access(all) let ticker: String             // e.g., "MICSAL"
        access(all) let commonName: String         // e.g., "Largemouth Bass"
        access(all) let scientificName: String     // e.g., "Micropterus salmoides"
        access(all) let family: String             // e.g., "Centrarchidae"
        access(all) let habitat: String            // e.g., "Freshwater"
        access(all) let averageWeight: UFix64      // in pounds
        access(all) let averageLength: UFix64      // in inches
        access(all) let imageURL: String           // species reference image
        access(all) let description: String        // species description
        access(all) let firstCatchDate: UInt64?    // timestamp of first verified catch
        access(all) let rarityTier: UInt8          // 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary
    }

    // Contract Views
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>(),
            Type<FungibleTokenMetadataViews.TotalSupply>()
        ]
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(url: self.speciesMetadata.imageURL),
                    mediaType: "image/jpeg"
                )
                return FungibleTokenMetadataViews.FTDisplay(
                    name: self.speciesMetadata.commonName.concat(" Coin"),
                    symbol: self.speciesMetadata.ticker,
                    description: self.speciesMetadata.description,
                    externalURL: MetadataViews.ExternalURL("https://derbyfish.com/species/".concat(self.speciesMetadata.speciesCode.toLower())),
                    logos: MetadataViews.Medias([media]),
                    socials: {
                        "website": MetadataViews.ExternalURL("https://derbyfish.com"),
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/derbyfish")
                    }
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(totalSupply: self.totalSupply)
        }
        return nil
    }

    // Vault Resource
    access(all) resource Vault: FungibleToken.Vault {
        access(all) var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                {SPECIES_CODE}Coin.totalSupply = {SPECIES_CODE}Coin.totalSupply - self.balance
                emit TokensBurned(amount: self.balance, from: self.owner?.address)
            }
            self.balance = 0.0
        }

        access(all) view fun getViews(): [Type] {
            return {SPECIES_CODE}Coin.getContractViews(resourceType: nil)
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return {SPECIES_CODE}Coin.resolveContractView(resourceType: nil, viewType: view)
        }

        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {Type<@{SPECIES_CODE}Coin.Vault>(): true}
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return type == Type<@{SPECIES_CODE}Coin.Vault>()
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{SPECIES_CODE}Coin.Vault {
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }

        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @{SPECIES_CODE}Coin.Vault
            self.balance = self.balance + vault.balance
            vault.balance = 0.0
            destroy vault
        }

        access(all) fun createEmptyVault(): @{SPECIES_CODE}Coin.Vault {
            return <-create Vault(balance: 0.0)
        }
    }

    // Minter Resource - Admin only
    access(all) resource Minter {
        
        access(all) fun mintForCatch(amount: UFix64, fishId: UInt64, angler: Address): @{SPECIES_CODE}Coin.Vault {
            pre {
                amount == 1.0: "Only 1 coin per verified catch"
            }
            
            {SPECIES_CODE}Coin.totalSupply = {SPECIES_CODE}Coin.totalSupply + amount
            
            emit TokensMinted(amount: amount, to: angler)
            emit CatchVerified(fishId: fishId, angler: angler, amount: amount)
            
            return <-create Vault(balance: amount)
        }

        access(all) fun mintBatch(recipients: {Address: UFix64}): @{Address: {SPECIES_CODE}Coin.Vault} {
            let vaults: @{Address: {SPECIES_CODE}Coin.Vault} <- {}
            
            for recipient in recipients.keys {
                let amount = recipients[recipient]!
                {SPECIES_CODE}Coin.totalSupply = {SPECIES_CODE}Coin.totalSupply + amount
                
                let vault <- create Vault(balance: amount)
                let oldVault <- vaults[recipient] <- vault
                destroy oldVault
                
                emit TokensMinted(amount: amount, to: recipient)
            }
            
            return <-vaults
        }
    }

    // Public functions
    access(all) fun createEmptyVault(vaultType: Type): @{SPECIES_CODE}Coin.Vault {
        pre {
            vaultType == Type<@{SPECIES_CODE}Coin.Vault>(): "Vault type mismatch"
        }
        return <-create Vault(balance: 0.0)
    }

    access(all) view fun getSpeciesMetadata(): SpeciesMetadata {
        return self.speciesMetadata
    }

    // Contract initialization
    init(
        speciesCode: String,
        ticker: String,
        commonName: String,
        scientificName: String,
        family: String,
        habitat: String,
        averageWeight: UFix64,
        averageLength: UFix64,
        imageURL: String,
        description: String,
        rarityTier: UInt8
    ) {
        // Validate inputs
        pre {
            speciesCode.length <= 20: "Species code too long"
            ticker.length <= 6: "Ticker too long"
            rarityTier >= 1 && rarityTier <= 5: "Invalid rarity tier"
        }

        self.totalSupply = 0.0
        
        // Set immutable species metadata
        self.speciesMetadata = SpeciesMetadata(
            speciesCode: speciesCode,
            ticker: ticker,
            commonName: commonName,
            scientificName: scientificName,
            family: family,
            habitat: habitat,
            averageWeight: averageWeight,
            averageLength: averageLength,
            imageURL: imageURL,
            description: description,
            firstCatchDate: nil,
            rarityTier: rarityTier
        )

        // Set storage paths using species code
        self.VaultStoragePath = StoragePath(identifier: speciesCode.concat("CoinVault"))!
        self.VaultPublicPath = PublicPath(identifier: speciesCode.concat("CoinReceiver"))!
        self.MinterStoragePath = StoragePath(identifier: speciesCode.concat("CoinMinter"))!

        // Create and store minter
        let minter <- create Minter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
    }
}
```

## Implementation Examples

### Example 1: Largemouth Bass Coin

**Contract Name**: `MICROPTERUSSALMOIDESCoin.cdc`

**Deployment Parameters**:
```javascript
{
  "speciesCode": "MICROPTERUS_SALMOIDES",
  "ticker": "MICSAL",
  "commonName": "Largemouth Bass",
  "scientificName": "Micropterus salmoides",
  "family": "Centrarchidae",
  "habitat": "Freshwater",
  "averageWeight": 3.5,
  "averageLength": 15.0,
  "imageURL": "https://derbyfish.com/images/species/largemouth-bass.jpg",
  "description": "The largemouth bass is a carnivorous freshwater gamefish in the sunfish family, native to eastern North America but widely introduced elsewhere.",
  "rarityTier": 2
}
```

### Example 2: Brown Trout Coin

**Contract Name**: `SALMOTRUTTACoin.cdc`

**Deployment Parameters**:
```javascript
{
  "speciesCode": "SALMO_TRUTTA",
  "ticker": "SALTR",
  "commonName": "Brown Trout",
  "scientificName": "Salmo trutta",
  "family": "Salmonidae",
  "habitat": "Freshwater",
  "averageWeight": 2.0,
  "averageLength": 12.0,
  "imageURL": "https://derbyfish.com/images/species/brown-trout.jpg",
  "description": "The brown trout is a European species of salmonid fish that has been widely introduced into suitable environments globally.",
  "rarityTier": 3
}
```

## Rarity Tier System

| Tier | Name | Description | Expected % of Total Catches |
|------|------|-------------|---------------------------|
| 1 | Common | Abundant species, easy to catch | 50-60% |
| 2 | Uncommon | Moderately common species | 25-30% |
| 3 | Rare | Less common, skilled anglers | 10-15% |
| 4 | Epic | Difficult to catch, specific conditions | 3-7% |
| 5 | Legendary | Extremely rare, trophy fish | <3% |

## Deployment Process

### 1. Species Research
- Verify scientific name accuracy
- Confirm common name usage
- Research habitat and physical characteristics
- Assign appropriate rarity tier

### 2. Contract Generation
- Replace all `{SPECIES_CODE}` placeholders with actual species code
- Replace all `{SPECIES_CODE}Coin` with actual contract name
- Validate all metadata fields

### 3. Deployment Checklist
- [ ] Unique species code (no conflicts)
- [ ] Unique ticker symbol (no conflicts)
- [ ] Valid scientific name
- [ ] Appropriate rarity tier
- [ ] High-quality species image URL
- [ ] Comprehensive description

### 4. Post-Deployment
- Register contract address in species registry
- Update frontend species database
- Add trading pair configurations
- Set up monitoring and analytics

## Contract Registry

Maintain a central registry of all deployed species coins:

```json
{
  "species_contracts": {
    "MICROPTERUS_SALMOIDES": {
      "contract_name": "MICROPTERUSSALMOIDESCoin",
      "contract_address": "0x...",
      "ticker": "MICSAL",
      "common_name": "Largemouth Bass",
      "rarity_tier": 2,
      "deployment_date": "2024-01-15",
      "total_supply": 1247,
      "active": true
    }
  }
}
```

## Integration Points

### With Fish NFT Contract
```cadence
// When minting Fish NFT, also mint species coin
let speciesCoin = getAccount(speciesContractAddress)
    .contracts.borrow<&{SPECIES_CODE}Coin>(name: "{SPECIES_CODE}Coin")
    
let minter = self.account.storage.borrow<&{SPECIES_CODE}Coin.Minter>(from: {SPECIES_CODE}Coin.MinterStoragePath)
let newCoins <- minter.mintForCatch(amount: 1.0, fishId: fishNFT.id, angler: angler)
```

### With BaitCoin Ecosystem
- Enable BaitCoin ↔ SpeciesCoin trading
- Price discovery through AMM pools
- Private sales for new species launches

## Security Considerations

1. **Immutable Metadata**: Species data cannot be changed after deployment
2. **Admin-Only Minting**: Only authorized minters can create tokens
3. **One Coin Per Catch**: Enforce 1:1 ratio with verified catches
4. **Audit Requirements**: Each contract should be audited before mainnet deployment

## Future Enhancements

1. **Seasonal Multipliers**: Bonus tokens during spawning seasons
2. **Location Bonuses**: Extra tokens for catches in specific areas
3. **Gear Bonuses**: Multipliers for specific fishing methods
4. **Tournament Integration**: Special tournament species coins
5. **Cross-Chain Bridging**: Enable species coins on other blockchains

## Conclusion

This template ensures consistent, scalable implementation of species coins across the entire DerbyFish ecosystem while maintaining uniqueness and preventing conflicts between different fish species tokens. 