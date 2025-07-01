# DerbyFish: Tokenizing the Sport of Fishing

## Executive Summary

DerbyFish is revolutionizing competitive and recreational fishing by combining blockchain technology with real-world angling. Our platform introduces **Bait Coin**, a stable, branded USDC wrapper, and **Species Coins**, tokenized representations of real fish species — minted only through verified catches.

Through NFTs, fungible tokens, and in-app earning mechanics, DerbyFish transforms fishing into a new kind of digital economy where verified catches are both trophies and assets.

## Core Concepts

### Bait Coin (BAIT)
- **1:1 pegged to USDC**
- Functions as both:
  - A stable, branded in-app currency
  - The base token for all economic activity within DerbyFish's ecosystem

### Species Coins
- Each fish species has its own unique, tradable token
- **Minting Process**:
  1. Catch a fish
  2. Validate through DerbyFish's BHRV process: **Bump, Hero, Release, Validate**
  3. Verified catch mints:
     - 1 unique FishNFT (non-fungible, identity-linked)
     - 1 Species Coin (fungible, species-linked)

- **Scarcity is organic**:
  - First-ever catch of a species mints the first token (supply = 1)
  - Each additional verified catch adds exactly one more coin to that species' total supply

### FishNFTs and FishCards
- **FishNFT**: Immutable proof of a catch, stored in a custodial Flow Blockchain wallet integrated into the DerbyFish app
- **FishCards**: Fungible derivatives of FishNFTs, carrying identical metadata
- Tradable within the FishDEX, our decentralized marketplace

## Earning and Trading

DerbyFish acts as a private buyer for Species Coins:
- Fishermen can sell coins back to DerbyFish at a set BAIT exchange rate — effectively earning stable, real-world value for their catches
- Once DerbyFish accumulates significant holdings of a Species Coin:
  - We establish a BAIT/Species Coin Liquidity Pool using an Automated Market Maker (AMM)
  - Open market trading begins, with price driven by supply, demand, and ecosystem participation

Fishermen have two options:
1. Sell Species Coins directly to DerbyFish for BAIT
2. Participate in the open market via the FishDEX

## Why This Matters

DerbyFish creates a circular, self-validating economy:
**Catch a fish → Mint an NFT and Species Coin → Earn BAIT → Trade, hold, or reinvest**

Real-world fishing achievements directly fuel token creation, adding measurable value to angling beyond tradition or competition.

This system:
✅ **Incentivizes sustainable, verified fishing**  
✅ **Introduces authentic scarcity into the token economy**  
✅ **Aligns blockchain with real-life activity, bridging crypto and consumer recreation**  
✅ **Creates new income opportunities for anglers globally**

## The Bold Future of Fishing

Fishing meets Web3 — not as a gimmick, but as a robust, participatory economic layer powered by verified human achievement.

**DerbyFish isn't just an app. It's the future of fishing, tokenized.**

---

## Technical Implementation

### Token Mechanics
- **Bait Coin**: Strict 1:1 USDC backing with minting/burning via USDC deposits and KYC-enabled redemptions
- **Species Coins**: 1 coin per verified Fish NFT mint, uncapped supply with natural issuance control
- **Initial Distribution**: Private in-app sale followed by AMM liquidity pool launch

### Economic Flows
- **FishCards ↔ Bait**: Dynamic market-driven exchange rates with transaction fees
- **SpeciesCoin ↔ Bait Market**: AMM-based DEX with DerbyFish as initial liquidity provider
- **Use Cases**: Derby tickets, memberships, merchandise, FishCards, Fish Packs, merchant integration

### Technical Architecture
- **Cadence Contracts**: FungibleToken standards with upgradeability patterns
- **Bridging**: LayerZero/Stargate for USDC inflows
- **Wallet Integration**: Custodial Flow accounts via Dapper/Modd® SDK
- **Compliance**: In-app KYC for large redemptions, mandatory for merchant partnerships

### Anti-Fraud & Security
- **BHRV Validation**: NFT minting strictly tied to proprietary verification process
- **Onboarding**: Custodial wallets eliminate crypto literacy requirements
- **Liquidity Strategy**: Dual role as buyer and market maker stabilizes early economics
- **Audits**: Independent smart-contract audits scheduled post-MVP

---

## Next Steps

1. Draft Cadence contract templates for Bait & SpeciesCoin
2. Design private-sale UI for initial SpeciesCoin distribution  
3. Integrate LayerZero bridge for USDC inflows
4. Build KYC & redemption backend workflows
5. Plan first smart-contract audit