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

## Contract Architecture

### Core Components

**1. FungibleToken Implementation**
- Standard Flow FungibleToken interface compliance
- Vault resource for token storage and transfers
- Total supply tracking (1 coin = 1 verified catch)

**2. Species Metadata System**
- **Immutable Core**: Species code, ticker, scientific name, family, data year
- **Mutable Descriptive**: Common name, habitat, averages, images, descriptions
- **Regional Data**: Population trends, threats, regulations by geographic region
- **Temporal Tracking**: Yearly metadata versions with historical archives

**3. Administrative Resources**
- **Minter**: Controlled token creation (1 coin per verified catch)
- **MetadataAdmin**: Update species information with validation and event logging

### Advanced Features

**4. Fish NFT Integration**
- `getSpeciesInfo()`: Standard data interface for Fish NFT contracts
- `recordCatchForSpecies()`: Hook for Fish NFT catch verification
- `getCatchCount()`: Total verified catches for the species

**5. BaitCoin Exchange System**
- Exchange rate storage for species coin ↔ BaitCoin conversion
- Admin-controlled rate updates with event logging
- Foundation for dual-token economy

**6. Regional Intelligence**
- `RegionalPopulation`: Population trends, threats, protected areas by region
- `RegionalRegulations`: Size limits, bag limits, closed seasons by jurisdiction
- Support for region-specific commercial pricing

**7. Conservation Analytics**
- `isEndangered()`: Boolean conservation status check
- `getConservationTier()`: 1-5 scale for trading algorithms
- Integration with IUCN conservation status standards

**8. Community Data Curation**
- `DataUpdate`: Structure for community-submitted metadata improvements
- Submission system for expert contributions (marine biologists, researchers)
- Admin approval workflow for data quality control

**9. Bulk Operations**
- `updateMetadataBatch()`: Efficient multiple field updates
- `addMultipleRegions()`: Bulk regional data import
- Support for scientific database integration

**10. FishDEX Query Interface**
- `getRegionsWithData()`: Available regional data discovery
- `hasCompleteMetadata()`: Data quality indicator
- `getDataCompleteness()`: 1-10 completeness score
- Optimized for trading platform integration

## Economic Model

**Supply Mechanism**: 1 species coin minted per verified fish catch
**Scarcity Model**: Rare/endangered species naturally have lower token supply
**Exchange Integration**: Standard FungibleToken interface enables DEX trading
**Cross-Token Utility**: BaitCoin exchange rates create ecosystem liquidity

## Data Intelligence Categories

**Biological**: Lifespan, diet, predators, spawning behavior, migration patterns
**Geographic**: Native regions, current range, water types, invasive status  
**Economic**: Regional commercial values, tourism impact, ecosystem role
**Recreational**: Best baits, fight ratings, culinary quality, catch difficulty
**Regulatory**: Size/bag limits, closed seasons, license requirements by region
**Conservation**: IUCN status, population trends, threats, protected areas
**Research**: Scientific priority, genetic markers, active study programs
**Records**: World record weight/length with location and date

## Validation & Safety

**Input Validation**: Rating scales (1-10), conservation status verification
**Regional Safety**: Null-safe regional data access with fallbacks
**Temporal Integrity**: Immutable core identity with mutable descriptive fields
**Admin Controls**: Restricted minting and metadata modification capabilities

## Integration Points

**Fish NFT Contracts**: Species data lookup and catch recording hooks
**BaitCoin Contract**: Exchange rate queries and conversion mechanisms  
**FishDEX Platform**: Rich query APIs for trading intelligence
**Scientific Databases**: Bulk import capabilities for research data
**Community Systems**: Expert contributor workflows and data validation

This template creates species coins that function as comprehensive biodiversity data packages, enabling sophisticated trading while supporting conservation awareness and scientific research.

### Records & Achievements
Track world records and competitive achievements:
- World record weight, location, and date
- World record length, location, and date (separate from weight record)
- Regional records and tournament data
- Achievement milestones
