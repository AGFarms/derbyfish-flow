# BaitCoin Contract Overview

## What is BaitCoin?

BaitCoin is a custom cryptocurrency token built on the Flow blockchain for the DerbyFish ecosystem. It's designed as a 1:1 pegged token with USDF (a bridged token from Ethereum), meaning 1 BAIT token always equals 1 USDF token in value.

## Key Features

### 🪙 Token Basics
- **Name**: BAIT Coin
- **Symbol**: BAIT
- **Decimals**: 8 (allowing for precise fractional amounts)
- **Total Supply**: Starts at 0 and grows as users swap USDF for BAIT
- **Website**: https://derby.fish

### 🔄 Token Swapping
The contract enables seamless conversion between USDF and BAIT tokens:
- **USDF → BAIT**: Users can swap their USDF tokens for BAIT tokens
- **BAIT → USDF**: Users can swap their BAIT tokens back to USDF tokens
- **1:1 Exchange Rate**: Always maintains a 1:1 ratio between the tokens

### 🏦 Vault System
- **Personal Vaults**: Each user has their own secure storage for BAIT tokens
- **Contract Vault**: The contract maintains a USDF vault to facilitate swaps
- **Automatic Setup**: Vaults are created automatically when needed

## How It Works

### For Regular Users

1. **Getting BAIT Tokens**:
   - Send USDF tokens to the contract
   - Receive an equal amount of BAIT tokens in your personal vault
   - Your USDF is stored in the contract's vault for future swaps

2. **Converting Back to USDF**:
   - Send BAIT tokens to the contract
   - Receive an equal amount of USDF tokens
   - Your BAIT tokens are "burned" (removed from circulation)

3. **Token Management**:
   - Check your BAIT balance anytime
   - Send BAIT to other users
   - View token information and metadata

### For Administrators

The contract includes special admin functions for:
- **Minting BAIT**: Create new BAIT tokens for specific users
- **Burning BAIT**: Remove BAIT tokens from circulation
- **Withdrawing USDF**: Move USDF from the contract to specific addresses
- **Updating Metadata**: Change token logo, description, or other information

## Security Features

### 🔒 Access Control
- **Admin-Only Functions**: Critical operations require admin privileges
- **User Authorization**: Users must authorize transactions involving their tokens
- **Capability System**: Uses Flow's capability system for secure access control

### 🛡️ Safety Checks
- **Balance Verification**: Prevents withdrawing more tokens than available
- **Amount Validation**: Ensures swap amounts are greater than zero
- **Vault Existence**: Checks that required vaults exist before operations

## Token Information & Metadata

### 📊 Display Information
- **Logo**: Custom logo hosted at https://derby.fish/bait-coin-logo.png
- **Description**: "BAIT COIN - A 1:1 pegged USDF token for the DerbyFish ecosystem"
- **Social Links**: Website and Twitter integration
- **Real-time Data**: Total supply and balance information

### 🔍 View Functions
Users can query:
- Current token balance
- Total supply in circulation
- Token metadata and display information
- Supported vault types

## Events & Notifications

The contract emits events for important actions:
- **TokensInitialized**: When the contract is first deployed
- **USDFToBaitSwap**: When someone swaps USDF for BAIT
- **BaitToUSDFSwap**: When someone swaps BAIT for USDF
- **LogoUrlUpdated**: When the token logo is changed
- **MetadataUpdated**: When token information is updated

## Technical Architecture

### 🏗️ Core Components
- **Vault Resource**: Main storage for user tokens
- **Admin Resource**: Manages administrative functions
- **Minter Resource**: Handles token creation
- **AdminManager Resource**: Manages admin permissions

### 🔗 Integration Points
- **FungibleToken Standard**: Implements Flow's standard token interface
- **MetadataViews**: Provides rich token information
- **USDF Integration**: Seamlessly works with bridged USDF tokens

## Use Cases

### 🎣 DerbyFish Ecosystem
- **In-Game Currency**: Use BAIT for DerbyFish game features
- **Rewards System**: Earn BAIT through gameplay
- **Trading**: Exchange BAIT with other players
- **Staking**: Potentially stake BAIT for rewards (future feature)

### 💱 DeFi Integration
- **Liquidity Pools**: Provide liquidity for BAIT/USDF trading pairs
- **Yield Farming**: Earn rewards by providing BAIT liquidity
- **Cross-Chain**: Bridge BAIT to other blockchains

## Getting Started

1. **Setup Vault**: Run the vault creation transaction
2. **Get USDF**: Acquire USDF tokens (bridged from Ethereum)
3. **Swap to BAIT**: Exchange USDF for BAIT tokens
4. **Use in DerbyFish**: Spend BAIT in the game ecosystem
5. **Swap Back**: Convert BAIT back to USDF when needed

## Benefits

- **Stability**: 1:1 peg with USDF provides price stability
- **Efficiency**: Fast and cheap transactions on Flow
- **Integration**: Seamlessly works with DerbyFish ecosystem
- **Transparency**: All transactions are recorded on-chain
- **Security**: Built on Flow's secure and decentralized network

---

*BaitCoin is designed to be the primary currency for the DerbyFish ecosystem, providing a stable, efficient, and user-friendly way to interact with the game and its features.*
