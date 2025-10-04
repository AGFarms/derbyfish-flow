# BaitCoin Contract Overview

## What is BaitCoin?

BaitCoin is a custom cryptocurrency token built on the Flow blockchain for the DerbyFish ecosystem. It's designed as a 1:1 pegged token with FUSD (a bridged token from Ethereum), meaning 1 BAIT token always equals 1 FUSD token in value. The contract is deployed at address `0xed2202de80195438` on Flow mainnet.

## Key Features

### 🪙 Token Basics
- **Name**: BAIT Coin
- **Symbol**: BAIT
- **Decimals**: 8 (allowing for precise fractional amounts)
- **Total Supply**: Starts at 0 and grows as users swap FUSD for BAIT
- **Website**: https://derby.fish

### 🔄 Token Swapping
The contract enables seamless conversion between FUSD and BAIT tokens:
- **FUSD → BAIT**: Users can swap their FUSD tokens for BAIT tokens
- **BAIT → FUSD**: Users can swap their BAIT tokens back to FUSD tokens
- **1:1 Exchange Rate**: Always maintains a 1:1 ratio between the tokens

### 🏦 Vault System
- **Personal Vaults**: Each user has their own secure storage for BAIT tokens
- **Contract Vault**: The contract maintains a FUSD vault to facilitate swaps
- **Vault Creation**: Users must run the `createAllVault.cdc` transaction to set up their vaults

## How It Works

### For Regular Users

1. **Getting BAIT Tokens**:
   - First, run `createAllVault.cdc` to set up your BAIT vault
   - Run `swapFusdForBait.cdc` transaction with your desired FUSD amount
   - Receive an equal amount of BAIT tokens in your personal vault
   - Your FUSD is stored in the contract's vault for future swaps

2. **Converting Back to FUSD**:
   - Run `swapBaitForFusd.cdc` transaction with your desired BAIT amount
   - Receive an equal amount of FUSD tokens
   - Your BAIT tokens are "burned" (removed from circulation)

3. **Token Management**:
   - Check your BAIT balance anytime
   - Send BAIT to other users
   - View token information and metadata

### For Administrators

The contract includes special admin functions for:
- **Minting BAIT**: Create new BAIT tokens for specific users (via `adminMintBait.cdc`)
- **Burning BAIT**: Remove BAIT tokens from circulation (via `adminBurnBait.cdc`)
- **Withdrawing FUSD**: Move FUSD from the contract to specific addresses (via `withdrawContractUsdf.cdc`)
- **Updating Metadata**: Change token logo, description, or other information
- **Direct Token Burning**: The `burnTokens()` function reduces total supply without requiring vault access

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
- **USDFToBaitSwap**: When someone swaps FUSD for BAIT
- **BaitToUSDFSwap**: When someone swaps BAIT for FUSD
- **LogoUrlUpdated**: When the token logo is changed
- **MetadataUpdated**: When token information is updated

## Technical Architecture

### 🏗️ Core Components
- **Vault Resource**: Main storage for user tokens at `/storage/baitCoinVault`
- **Admin Resource**: Manages administrative functions at `/storage/baitCoinAdmin`
- **Minter Resource**: Handles token creation at `/storage/baitCoinMinter`
- **AdminManager Resource**: Manages admin permissions at `/storage/baitCoinAdminManager`
- **Contract FUSD Vault**: Stores FUSD for swaps at `/storage/EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabedVault`

### 🔗 Integration Points
- **FungibleToken Standard**: Implements Flow's standard token interface
- **MetadataViews**: Provides rich token information
- **FUSD Integration**: Seamlessly works with bridged FUSD tokens from Ethereum

## Use Cases

### 🎣 DerbyFish Ecosystem
- **In-Game Currency**: Use BAIT for DerbyFish game features
- **Rewards System**: Earn BAIT through gameplay
- **Trading**: Exchange BAIT with other players
- **Staking**: Potentially stake BAIT for rewards (future feature)

### 💱 DeFi Integration
- **Liquidity Pools**: Provide liquidity for BAIT/FUSD trading pairs
- **Yield Farming**: Earn rewards by providing BAIT liquidity
- **Cross-Chain**: Bridge BAIT to other blockchains

## Available Transactions & Scripts

### User Transactions
- **`createAllVault.cdc`**: Set up BAIT vault for a user
- **`swapFusdForBait.cdc`**: Exchange FUSD for BAIT tokens
- **`swapBaitForFusd.cdc`**: Exchange BAIT tokens for FUSD
- **`sendBait.cdc`**: Send BAIT tokens to another user
- **`sendFusd.cdc`**: Send FUSD tokens to another user

### Admin Transactions
- **`adminMintBait.cdc`**: Mint BAIT tokens to a specific address
- **`adminBurnBait.cdc`**: Burn BAIT tokens from admin's vault
- **`withdrawContractUsdf.cdc`**: Withdraw FUSD from contract vault

### Utility Scripts
- **`checkBaitBalance.cdc`**: Check BAIT balance for an address
- **`checkContractVaults.cdc`**: Check contract vault status
- **`checkContractUsdfBalance.cdc`**: Check contract's FUSD balance

## Getting Started

1. **Setup Vault**: Run the `createAllVault.cdc` transaction
2. **Get FUSD**: Acquire FUSD tokens (bridged from Ethereum)
3. **Swap to BAIT**: Run `swapFusdForBait.cdc` to exchange FUSD for BAIT tokens
4. **Use in DerbyFish**: Spend BAIT in the game ecosystem
5. **Swap Back**: Run `swapBaitForFusd.cdc` to convert BAIT back to FUSD when needed

## Benefits

- **Stability**: 1:1 peg with FUSD provides price stability
- **Efficiency**: Fast and cheap transactions on Flow
- **Integration**: Seamlessly works with DerbyFish ecosystem
- **Transparency**: All transactions are recorded on-chain
- **Security**: Built on Flow's secure and decentralized network

---

*BaitCoin is designed to be the primary currency for the DerbyFish ecosystem, providing a stable, efficient, and user-friendly way to interact with the game and its features.*
