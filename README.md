## DerbyFish Flow Tokenomics & Architecture

### Overview

DerbyFish creates the closest thing to real-life Pokémon through verified fish catching. The tokenomics is built on actual fish catches verified by the DerbyFish sanctioning body, creating a unique ecosystem where real-world fishing translates into digital assets.

**Core System Components**:

* **Fish NFTs**: Non-transferable digital assets representing verified fish catches, permanently owned by the angler who caught them
* **Species Coins**: Fungible tokens serving as fish dex, fish index, and decentralized exchange all-in-one (e.g., WalleyeCoin, BassCoin)
* **FishCards**: Tradeable NFT trading cards with randomized metadata reveals and royalties to original anglers
* **Bait**: A 1:1 USDC‑backed stablecoin for marketplace transactions and merchant integrations

### The Real Fish Catching Experience

When an angler catches a fish and gets verified by DerbyFish's sanctioning body, they receive a **Fish NFT** - a permanent, non-transferable digital asset that represents their actual catch. This NFT contains both public core information and private metadata fields:

**Core Public Information** (always visible):
- Species name and scientific classification
- Fish length and weight
- Catch timestamp and date
- Species code identifier
- Basic catch verification status

**Private Metadata Fields** (angler-controlled):
- Exact GPS coordinates and location details
- Water conditions (temperature, clarity, current)
- Weather data (conditions, moon phase, barometric pressure)
- Detailed gear information (rod, reel, line, bait/lure specifics)
- Fishing technique and presentation method
- Angler personal notes and catch story
- Photo metadata and verification hashes

These Fish NFTs are **forever owned by the angler** - they cannot be transferred or sold, representing a permanent record of their fishing achievements.

---

### 1. Species Coins: Fish Dex, Index & Exchange All-in-One

Once a Fish NFT is minted, a **species-specific coin** is automatically generated (e.g., WalleyeCoin for Walleye catches). These coins serve as a revolutionary **two-in-one system**:

**Fish Dex/Index Functions**:
Species coins contain comprehensive encyclopedic information about each fish species, stored directly in the contract metadata:

* **Biological Data**: Lifespan, diet, predators, spawning behavior, migration patterns, habitat preferences
* **Geographic Information**: Native regions, current range, water types, invasive status, seasonal movements  
* **Economic Impact**: Regional commercial values, tourism impact, ecosystem role, fishery importance
* **Recreational Details**: Best baits, fight ratings, culinary quality, catch difficulty, angling techniques
* **Regulatory Framework**: Size/bag limits, closed seasons, license requirements by region, conservation rules
* **Conservation Status**: IUCN classification, population trends, threats, protected areas, restoration efforts
* **Scientific Research**: Research priority, genetic markers, active study programs, data gaps
* **Record Keeping**: World record weight/length with location and date, notable catches

**Decentralized Exchange Functions**:
- **Supply Mechanism**: Exactly 1 coin minted per verified fish catch, creating natural scarcity
- **Trading Integration**: Standard FungibleToken interface enables DEX trading and liquidity pools
- **Rarity Economics**: Rare/endangered species naturally have lower token supply, increasing value
- **Cross-Species Trading**: BaitCoin exchange rates create ecosystem-wide liquidity

#### FishCards: Tradeable NFTs with Randomized Reveals

Users can mint **FishCards** from other people's Fish NFTs, creating a unique trading card ecosystem:

**Core Data** (always included):
- Species name and scientific classification
- Fish length and basic catch info
- Timestamp and verification status

**Private Data Randomization**:
Each private metadata field gets an independent **coin toss** (50/50 chance) to determine if it appears on the FishCard:
- Location details (may or may not be revealed)
- Exact GPS coordinates (random reveal)
- Gear specifications (coin toss reveal)
- Weather conditions (random inclusion)
- Angling techniques (chance-based reveal)
- Personal angler notes (privacy-protected)

**Rarity & Economics**:
- Cards with more revealed fields become rarer (Common → Legendary)
- **Royalties**: Original angler receives royalties on all FishCard trades
- **Transferable**: Unlike Fish NFTs, FishCards can be bought, sold, and traded
- **Privacy Protection**: Sensitive data only revealed by chance, protecting angler privacy

#### Bait (Stablecoin)

* **Pegging & Reserves**: Strictly 1:1 backed by USDC. Reserves held in a multi‑sig vault with time‑locks and proof‑of‑reserves snapshots available in‑app.
* **Mint/Burn**: Users mint Bait by depositing USDC via in‑app custodial flows; burn by redeeming USDC on‑chain or through a KYC‑gate in the app.
* **Gas Sponsorship**: DerbyFish pays all Flow gas; users never see transaction fees.

---

### 2. Three-Tier Digital Asset System

#### Fish NFTs: Permanent Catch Records
* **Non-transferable**: Forever owned by the angler who caught the fish
* **Comprehensive Metadata**: 44+ fields covering catch details, location, gear, weather, technique
* **Verification Proof**: Immutable record of sanctioning body verification
* **Species Registration**: Links to species coin contracts for encyclopedic data
* **Privacy Control**: Angler controls which metadata fields are public vs private

#### Species Coins: Living Fish Encyclopedia
* **Encyclopedic Database**: Each coin contract contains comprehensive species information
* **Natural Scarcity**: Supply directly tied to verified catch numbers
* **Trading Mechanism**: Standard fungible token enabling DEX integration
* **Research Integration**: Connects to scientific databases and conservation data
* **Regional Data**: Location-specific regulations, seasons, and fishing information

#### FishCards: Randomized Trading Cards
* **Commit-Reveal Minting**: Secure randomness prevents manipulation
* **Independent Coin Flips**: Each private field has 50/50 reveal chance
* **Rarity Tiers**: More revealed fields = rarer cards (Common to Legendary)
* **Transferable Assets**: Can be bought, sold, and traded unlike Fish NFTs
* **Royalty System**: Original angler earns from all secondary sales
* **Privacy Preservation**: Protects sensitive location data through randomization

---

### 3. Fishdex & Badging System

* **On‑Chain Events**: `FishMinted` and `BadgeAwarded` events trigger off‑chain amplification to update the Fishdex UI.
* **Fishdex UI**: Displays species sightings, badge collections, gear logs, and geographic heatmaps.
* **Rewards**: First‑catch badges unlock UI achievements; can integrate bonus SpeciesCoin airdrops in future.

---

### 4. Marketplace & Economic Flows

#### FishCards ↔ Bait

* Fish trading‑card NFTs can be listed in the in‑app marketplace for Bait at dynamic, market‑driven prices.

#### SpeciesCoin ↔ Bait

* Initial private sale per species at a fixed price in Bait, handled by a `PrivateSale` contract.
* Post‑sale, DerbyFish seeds an AMM pool (`SpeciesCoin–Bait`) and reinvests a portion of fees to maintain liquidity.

#### Merchant & In‑Store Use Cases

* DerbyFish SDK for Web POS: Merchants accept Bait via custodial API; DerbyFish settles USDC off‑chain.

---

### 5. Security & Compliance

* **Multi‑Sig Vaults**: USDC reserves in 2‑of‑3 multi‑sig with 48‑hour timelock.
* **Audits**: Engage CertiK/Consensys for Cadence contracts; SOC 2 for backend.
* **KYC/AML**: All fiat on‑ramps/redemptions require in‑app KYC; small spot trades gas‑only.

---

### 6. UX & Onboarding

* **Custodial Accounts**: Email‑OTP flow via Dapper SDK abstracts Flow accounts.
* **Gasless**: All gas sponsored; users only see Bait balances.
* **Fiat On‑Ramp**: Single "Buy Bait" button routes through ACH, card, or crypto on‑ramp based on cost/latency.
* **Recovery**: Email‑based key recovery; optional social‑recovery through guardians.

---

### 7. Data Intelligence & Metadata

#### Species Coin Metadata Categories

* **Biological**: Lifespan, diet, predators, spawning behavior, migration patterns
* **Geographic**: Native regions, current range, water types, invasive status  
* **Economic**: Regional commercial values, tourism impact, ecosystem role
* **Recreational**: Best baits, fight ratings, culinary quality, catch difficulty
* **Regulatory**: Size/bag limits, closed seasons, license requirements by region
* **Conservation**: IUCN status, population trends, threats, protected areas
* **Research**: Scientific priority, genetic markers, active study programs
* **Records**: World record weight/length with location and date

#### Validation & Safety

* **Input Validation**: Rating scales (1-10), conservation status verification
* **Regional Safety**: Null-safe regional data access with fallbacks
* **Temporal Integrity**: Immutable core identity with mutable descriptive fields
* **Admin Controls**: Restricted minting and metadata modification capabilities

#### Integration Points

* **Fish NFT Contracts**: Species data lookup and catch recording hooks
* **BaitCoin Contract**: Exchange rate queries and conversion mechanisms  
* **FishDEX Platform**: Rich query APIs for trading intelligence
* **Scientific Databases**: Bulk import capabilities for research data
* **Community Systems**: Expert contributor workflows and data validation

---

### 8. Economic Model & Supply Mechanics

#### Supply Mechanism
* 1 species coin minted per verified fish catch
* Scarcity model: Rare/endangered species naturally have lower token supply
* Exchange integration: Standard FungibleToken interface enables DEX trading
* Cross-token utility: BaitCoin exchange rates create ecosystem liquidity

#### FishDEX Query Interface
* `getRegionsWithData()`: Available regional data discovery
* `hasCompleteMetadata()`: Data quality indicator
* `getDataCompleteness()`: 1-10 completeness score
* Optimized for trading platform integration

#### Bulk Operations
* `updateMetadataBatch()`: Efficient multiple field updates
* `addMultipleRegions()`: Bulk regional data import
* Support for scientific database integration

#### Community Data System
* `DataUpdate`: Structure for community-submitted metadata improvements
* Submission system for expert contributions (marine biologists, researchers)
* Admin approval workflow for data quality control

---

### 9. Smart Contract Architecture

#### FishNFT Contract

The FishNFT contract serves as the core of the DerbyFish ecosystem, implementing the NonFungibleToken standard with enhanced metadata capabilities.

**Key Features**:
* Immutable catch metadata storage
* Species registration and validation
* FishCard NFT minting with commit-reveal randomness
* MetadataViews implementation for rich NFT data

**Resources**:
* `NFT`: Core Fish NFT resource with comprehensive metadata
* `Collection`: Non-transferable NFT collection
* `FishCard`: Trading card NFT with randomized reveal mechanics
* `FishCardCollection`: Transferable card collection

**Transactions**:
* `setup_fish_nft_collection.cdc`: Initialize NFT collection
* `register_species.cdc`: Register new fish species
* `mint_fish_nft_with_species.cdc`: Mint comprehensive Fish NFT
* `mint_fish_nft.cdc`: Mint basic Fish NFT
* `setup_fish_card_collection.cdc`: Initialize FishCard collection
* `enable_fish_cards.cdc`: Enable card minting for NFT
* `commit_fish_card.cdc`: Initiate card minting with user salt
* `reveal_fish_card.cdc`: Complete card minting with randomness
* `transfer_fish_card.cdc`: Transfer cards between accounts

**Scripts**:
* `get_fish_nft_ids.cdc`: List owned NFT IDs
* `get_fish_nft_by_id.cdc`: Get NFT details
* `get_fish_card_ids.cdc`: List owned card IDs
* `get_fish_card_by_id.cdc`: Get card details

#### WalleyeCoin Contract

WalleyeCoin implements the FungibleToken standard with species-specific tracking and metadata.

**Key Features**:
* Independent NFT redemption tracking
* Rich token metadata via FungibleTokenMetadataViews
* Species-specific coin minting rules
* Comprehensive vault management

**Resources**:
* `Vault`: Standard FungibleToken vault with balance tracking
* `Administrator`: Admin resource for contract management
* `SpeciesCoinPublic`: Public interface for cross-contract coordination
* `Minter`: Controlled minting capability

**Transactions**:
* `setup_walleye_coin_account.cdc`: Initialize token vault
* `mint-species-coin.cdc`: Mint coins from verified NFT

**Scripts**:
* `get_walleye_coin_balance.cdc`: Check account balance

### Updated Tokenomics Vision

The DerbyFish tokenomy has evolved to emphasize:

1. **Decentralized Verification**:
   * Each species coin contract independently tracks NFT redemptions
   * Removed central redemption tracking for better scalability
   * Enhanced security through commit-reveal card minting

2. **Privacy-Preserving Features**:
   * FishCards with randomized metadata reveals
   * Core catch data always visible
   * Optional privacy for sensitive location data

3. **Modular Architecture**:
   * Independent species coin contracts
   * Separate NFT and card collections
   * Clear separation of concerns between contracts

4. **Enhanced Metadata**:
   * Rich NFT metadata via MetadataViews
   * Comprehensive FungibleTokenMetadataViews support
   * Structured species-specific token data

5. **Security Considerations**:
   * Non-transferable Fish NFTs
   * Transferable FishCards for trading
   * Secure randomness via commit-reveal scheme
   * Independent redemption tracking

This architecture provides a robust foundation for future ecosystem expansion while maintaining security and user privacy.

---

