## DerbyFish Flow Tokenomics & Architecture

### Overview

DerbyFish uses a dual‑token model on Flow:

* **Bait**: A 1:1 USDC‑backed stablecoin for in‑app purchases, marketplace transactions, and merchant integrations.
* **SpeciesCoins**: One fungible token contract per fish species (e.g., WalleyeCoin, BassCoin), minted by anglers when they verify a catch and mint a FishNFT.
* **FishNFTs**: Non‑fungible tokens representing the actual catch, storing full metadata (species, GPS, time, gear). Users can optionally mint **Trading‑Card NFTs** derived from their FishNFT.
* **Badges**: On‑chain, soulbound Badge NFTs granted on first‑catch per species (extendable to location or gear achievements).

---

### 1. Token Roles & Mechanics

#### Bait (Stablecoin)

* **Pegging & Reserves**: Strictly 1:1 backed by USDC. Reserves held in a multi‑sig vault with time‑locks and proof‑of‑reserves snapshots available in‑app.
* **Mint/Burn**: Users mint Bait by depositing USDC via in‑app custodial flows; burn by redeeming USDC on‑chain or through a KYC‑gate in the app.
* **Gas Sponsorship**: DerbyFish pays all Flow gas; users never see transaction fees.

#### SpeciesCoins (Per Species)

* **Deployment**: A `SpeciesCoinFactory` contract allows on‑chain registration of new species IDs and dynamic creation of fungible token contracts (e.g., `WalleyeCoin`).
* **Minting**: `mintSpeciesCoin(speciesID, 1)` is called automatically in the Fish‑mint transaction, crediting the angler with 1 token.
* **Supply**: Capped to the total number of FishNFTs ever minted for that species; future caps enforced via upgradeable contract governance.

---

### 2. NFT Architecture

#### FishNFT

* Implements `NonFungibleToken`, stores catch metadata (GPS, timestamp, gear, photos).
* Serves as the canonical proof of catch and key to minting SpeciesCoin.

#### Trading‑Card NFTs

* Users may mint up to an upgradeable limit of "card edition" NFTs from an existing FishNFT.
* Cards reference the FishNFT ID and optionally include or omit personal metadata for privacy.
* Card metadata and artwork templates managed via a central registry contract.

#### Badge NFTs

* On first‐catch per species, a soulbound Badge NFT is minted to the user's account.
* Badges include speciesID and timestamp metadata; non‑transferable.
* Extendable to other badge categories (locations, gear, leaderboards).

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

