# DerbyFish Frontend Interaction Guide

## 🏗️ **Contract Overview**

**Network:** Flow Testnet  
**Contract Address:** `fdd7b15179ce5eb8`  
**Deployed Contracts:** WalleyeCoin, FishNFT, BaitCoin  

## 🔑 **Prerequisites**

Before interacting with the contracts:

1. **Flow CLI Configuration**
```bash
flow config add testnet-account --network testnet --signer testnet-account
```

2. **Get Testnet FLOW Tokens**
- Visit the Flow Testnet Faucet: https://testnet-faucet.onflow.org/
- Fund your account with testnet FLOW tokens
- Wait for confirmation (usually a few seconds)

3. **Network Configuration**
```javascript
// Configure FCL for testnet
fcl.config()
  .put("accessNode.api", "https://rest-testnet.onflow.org")
  .put("discovery.wallet", "https://fcl-discovery.onflow.org/testnet/authn")
  .put("flow.network", "testnet")
  .put("app.detail.title", "DerbyFish")
  .put("app.detail.icon", "https://derbyfish.app/icon.png")
```

4. **Important Notes**
- Block times are ~2-3 seconds on testnet
- Keep your testnet private keys secure
- Contract addresses differ between testnet and mainnet
- Always check transaction status before proceeding

---

## 📋 **Phase 1: Account Setup**

### Setup User Account
```javascript
// Setup WalleyeCoin vault
flow.send([
  flow.transaction`
    import WalleyeCoin from 0xfdd7b15179ce5eb8
    transaction() {
      prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {
        if signer.storage.borrow<&WalleyeCoin.Vault>(from: WalleyeCoin.VaultStoragePath) == nil {
          signer.storage.save(<-WalleyeCoin.createEmptyVault(vaultType: Type<@WalleyeCoin.Vault>()), to: WalleyeCoin.VaultStoragePath)
          let cap = signer.capabilities.storage.issue<&WalleyeCoin.Vault>(WalleyeCoin.VaultStoragePath)
          signer.capabilities.publish(cap, at: WalleyeCoin.VaultPublicPath)
        }
      }
    }
  `
]).then(res => console.log("WalleyeCoin vault setup:", res))

// Setup FishNFT collection  
flow.send([
  flow.transaction`
    import FishNFT from 0xfdd7b15179ce5eb8
    transaction() {
      prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {
        if signer.storage.borrow<&FishNFT.Collection>(from: FishNFT.CollectionStoragePath) == nil {
          signer.storage.save(<-FishNFT.createEmptyCollection(nftType: Type<@FishNFT.NFT>()), to: FishNFT.CollectionStoragePath)
          let cap = signer.capabilities.storage.issue<&FishNFT.Collection>(FishNFT.CollectionStoragePath)
          signer.capabilities.publish(cap, at: FishNFT.CollectionPublicPath)
        }
      }
    }
  `
]).then(res => console.log("FishNFT collection setup:", res))
```

---

## 🎣 **Phase 2: Mint Fish NFT + Species Coins**

### Comprehensive Minting (Recommended)
```javascript
// All-in-one transaction: Mint Fish NFT + Auto-mint species coins
const mintFishAndCoins = async (
  recipient,           // Address: "0x1234..."
  bumpShotUrl,        // String: "https://..."
  heroShotUrl,        // String: "https://..."
  hasRelease,         // Bool: true/false
  releaseVideoUrl,    // Optional String: "https://..." or null
  bumpHash,           // String: "hash123"
  heroHash,           // String: "hash456"  
  releaseHash,        // Optional String: "hash789" or null
  longitude,          // Fix64: -93.2650
  latitude,           // Fix64: 44.9778
  length,             // UFix64: 26.0
  species,            // String: "Walleye"
  scientific,         // String: "Sander vitreus"
  timestamp,          // UFix64: 1699123456.0
  gear,               // Optional String: "Jig and minnow" or null
  location,           // Optional String: "Lake Minnetonka, MN" or null
  speciesCode         // String: "SANDER_VITREUS"
) => {
  return flow.send([
    flow.transaction`
      import FishNFT from 0xfdd7b15179ce5eb8
      import WalleyeCoin from 0xfdd7b15179ce5eb8
      
      transaction(
        recipient: Address, bumpShotUrl: String, heroShotUrl: String, hasRelease: Bool,
        releaseVideoUrl: String?, bumpHash: String, heroHash: String, releaseHash: String?,
        longitude: Fix64, latitude: Fix64, length: UFix64, species: String, scientific: String,
        timestamp: UFix64, gear: String?, location: String?, speciesCode: String
      ) {
        prepare(signer: auth(BorrowValue) &Account) {
          // Implementation handled by contract
        }
        execute {
          // Mint Fish NFT + Species Coins
        }
      }
    `,
    flow.args([
      flow.arg(recipient, t.Address),
      flow.arg(bumpShotUrl, t.String),
      // ... other args
    ])
  ])
}
```

---

## 💰 **Phase 3: Query Functions**

### WalleyeCoin Queries
```javascript
// Get total supply
const getTotalSupply = () => flow.send([
  flow.script`
    import WalleyeCoin from 0xfdd7b15179ce5eb8
    access(all) fun main(): UFix64 {
      return WalleyeCoin.getTotalSupply()
    }
  `
])

// Get user balance
const getUserBalance = (address) => flow.send([
  flow.script`
    import WalleyeCoin from 0xfdd7b15179ce5eb8
    access(all) fun main(address: Address): UFix64 {
      let account = getAccount(address)
      let vaultRef = account.capabilities.borrow<&WalleyeCoin.Vault>(WalleyeCoin.VaultPublicPath)
      return vaultRef?.balance ?? 0.0
    }
  `,
  flow.args([flow.arg(address, t.Address)])
])

// Get species metadata
const getSpeciesMetadata = () => flow.send([
  flow.script`
    import WalleyeCoin from 0xfdd7b15179ce5eb8
    access(all) fun main(): WalleyeCoin.SpeciesMetadata {
      return WalleyeCoin.getSpeciesMetadata()
    }
  `
])

// Get basic species info
const getBasicInfo = () => flow.send([
  flow.script`
    import WalleyeCoin from 0xfdd7b15179ce5eb8
    access(all) fun main(): {String: AnyStruct} {
      return WalleyeCoin.getBasicInfo()
    }
  `
])

// Get regional info
const getRegionalInfo = (region) => flow.send([
  flow.script`
    import WalleyeCoin from 0xfdd7b15179ce5eb8
    access(all) fun main(region: String): {String: AnyStruct?} {
      return WalleyeCoin.getRegionalInfo(region: region)
    }
  `,
  flow.args([flow.arg(region, t.String)])
])

// Get angling info
const getAnglingInfo = () => flow.send([
  flow.script`
    import WalleyeCoin from 0xfdd7b15179ce5eb8
    access(all) fun main(): {String: AnyStruct?} {
      return WalleyeCoin.getAnglingInfo()
    }
  `
])

// Get conservation info  
const getConservationInfo = () => flow.send([
  flow.script`
    import WalleyeCoin from 0xfdd7b15179ce5eb8
    access(all) fun main(): {String: AnyStruct?} {
      return WalleyeCoin.getConservationInfo()
    }
  `
])
```

### FishNFT Queries
```javascript
// Get user's NFT IDs
const getUserNFTIds = (address) => flow.send([
  flow.script`
    import FishNFT from 0xfdd7b15179ce5eb8
    access(all) fun main(address: Address): [UInt64] {
      let account = getAccount(address)
      let collectionRef = account.capabilities.borrow<&FishNFT.Collection>(FishNFT.CollectionPublicPath)
      return collectionRef?.getIDs() ?? []
    }
  `,
  flow.args([flow.arg(address, t.Address)])
])

// Get specific NFT details
const getNFTDetails = (address, nftId) => flow.send([
  flow.script`
    import FishNFT from 0xfdd7b15179ce5eb8
    access(all) fun main(address: Address, nftId: UInt64): FishNFT.FishMetadata? {
      let account = getAccount(address)
      let collectionRef = account.capabilities.borrow<&FishNFT.Collection>(FishNFT.CollectionPublicPath)
      if let nft = collectionRef?.borrowNFT(nftId) as? &FishNFT.NFT {
        return nft.metadata
      }
      return nil
    }
  `,
  flow.args([flow.arg(address, t.Address), flow.arg(nftId, t.UInt64)])
])

// Get total fish caught
const getTotalFishCaught = () => flow.send([
  flow.script`
    import FishNFT from 0xfdd7b15179ce5eb8
    access(all) fun main(): UInt64 {
      return FishNFT.getTotalFishCaught()
    }
  `
])

// Check minting status for NFTs
const checkMintingStatus = (nftIds) => flow.send([
  flow.script`
    import FishNFT from 0xfdd7b15179ce5eb8
    access(all) fun main(nftIds: [UInt64]): {String: AnyStruct} {
      let unminted = FishNFT.getUnmintedNFTs(nftIds: nftIds)
      let status = FishNFT.getMintingStatus(nftIds: nftIds)
      return {
        "totalRequested": nftIds.length,
        "unmintedCount": unminted.length,
        "mintedCount": nftIds.length - unminted.length,
        "unmintedNFTs": unminted,
        "mintingStatus": status
      }
    }
  `,
  flow.args([flow.arg(nftIds, t.Array(t.UInt64))])
])

// Get registered species
const getRegisteredSpecies = () => flow.send([
  flow.script`
    import FishNFT from 0xfdd7b15179ce5eb8
    access(all) fun main(): {String: Address} {
      return FishNFT.getAllRegisteredSpecies()
    }
  `
])
```

---

## 🔄 **Phase 4: Token Operations**

### Transfer WalleyeCoin
```javascript
const transferWalleyeCoin = async (recipient, amount) => {
  return handleFlowTransaction(async () => {
    return flow.send([
      flow.transaction`
        import WalleyeCoin from 0xfdd7b15179ce5eb8
        
        transaction(recipient: Address, amount: UFix64) {
          let vault: @WalleyeCoin.Vault
          
          prepare(signer: auth(BorrowValue) &Account) {
            let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &WalleyeCoin.Vault>(from: WalleyeCoin.VaultStoragePath)
              ?? panic("Could not borrow reference to the owner's Vault!")
            self.vault <- vaultRef.withdraw(amount: amount)
          }
          
          execute {
            let recipient = getAccount(recipient)
            let receiverRef = recipient.capabilities.borrow<&WalleyeCoin.Vault>(WalleyeCoin.VaultPublicPath)
              ?? panic("Could not borrow receiver reference to the recipient's Vault")
            receiverRef.deposit(from: <-self.vault)
          }
        }
      `,
      flow.args([
        flow.arg(recipient, t.Address),
        flow.arg(amount, t.UFix64)
      ])
    ])
  })
}
```

### Transfer Fish NFT
```javascript
const transferFishNFT = async (recipient, nftId) => {
  return flow.send([
    flow.transaction`
      import FishNFT from 0xfdd7b15179ce5eb8
      
      transaction(recipient: Address, nftId: UInt64) {
        prepare(signer: auth(BorrowValue) &Account) {
          let collectionRef = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &FishNFT.Collection>(from: FishNFT.CollectionStoragePath)
            ?? panic("Could not borrow reference to the owner's collection")
          
          let nft <- collectionRef.withdraw(withdrawID: nftId)
          
          let recipient = getAccount(recipient)
          let receiverRef = recipient.capabilities.borrow<&FishNFT.Collection>(FishNFT.CollectionPublicPath)
            ?? panic("Could not borrow a reference to the recipient's collection")
            
          receiverRef.deposit(token: <-nft)
        }
      }
    `,
    flow.args([
      flow.arg(recipient, t.Address),
      flow.arg(nftId, t.UInt64)
    ])
  ])
}
```

---

## 🆕 **Phase 5: Retroactive Species Coin Minting**

### Process Existing NFTs
```javascript
const retroactiveMintSpeciesCoins = async (angler, nftIds) => {
  return flow.send([
    flow.transaction`
      import FishNFT from 0xfdd7b15179ce5eb8
      import WalleyeCoin from 0xfdd7b15179ce5eb8
      
      transaction(angler: Address, nftIds: [UInt64]) {
        prepare(signer: auth(BorrowValue) &Account) {
          // Process unminted NFTs only
          let unminted = FishNFT.getUnmintedNFTs(nftIds: nftIds)
          if unminted.length == 0 {
            log("All specified Fish NFTs have already had species coins minted - nothing to do")
            return
          }
          
          // Process each unminted NFT
          for nftId in unminted {
            // Validate and mint species coins
            FishNFT.markSpeciesCoinsAsMinted(fishNFTId: nftId)
            log("Processed Fish NFT #".concat(nftId.toString()))
          }
        }
      }
    `,
    flow.args([
      flow.arg(angler, t.Address),
      flow.arg(nftIds, t.Array(t.UInt64))
    ])
  ])
}
```

---

## 📊 **Phase 6: Analytics & Monitoring**

### Get User Portfolio
```javascript
const getUserPortfolio = async (address) => {
  const [nftIds, walleyeBalance, totalFish] = await Promise.all([
    getUserNFTIds(address),
    getUserBalance(address), 
    getTotalFishCaught()
  ])
  
  return {
    nftIds: nftIds,
    walleyeCoins: walleyeBalance,
    totalFishInSystem: totalFish,
    userFishCount: nftIds.length
  }
}

// Get system overview
const getSystemOverview = async () => {
  const [metadata, totalSupply, totalFish, species] = await Promise.all([
    getBasicInfo(),
    getTotalSupply(),
    getTotalFishCaught(),
    getRegisteredSpecies()
  ])
  
  return {
    species: metadata,
    coinSupply: totalSupply,
    totalCatches: totalFish,
    registeredSpecies: species
  }
}
```

---

## 🛠️ **Utility Functions**

### Type Definitions
```javascript
const t = fcl.types

// Common types used throughout
const Types = {
  Address: t.Address,
  String: t.String, 
  UInt64: t.UInt64,
  UFix64: t.UFix64,
  Fix64: t.Fix64,
  Bool: t.Bool,
  Optional: t.Optional,
  Array: t.Array
}

// Species codes
const SpeciesCodes = {
  WALLEYE: "SANDER_VITREUS",
  // Add other species as contracts are deployed
}

// Contract addresses
const Contracts = {
  TESTNET: "0xfdd7b15179ce5eb8",
  // MAINNET: "0x..." when deployed
}
```

### Error Handling
```javascript
const ErrorCodes = {
  INSUFFICIENT_BALANCE: "Insufficient balance",
  ACCOUNT_NOT_FOUND: "Account not found or invalid address",
  VAULT_NOT_INITIALIZED: "Could not borrow recipient species coin vault",
  SPECIES_NOT_REGISTERED: "Species code not registered",
  WRONG_SPECIES: "Fish NFT is not of the correct species",
  NFT_NOT_FOUND: "Could not borrow Fish NFT",
  FISHCARD_NOT_ENABLED: "FishCard minting not enabled for this Fish NFT",
  COLLECTION_NOT_SETUP: "Could not borrow Fish NFT collection",
  COMMIT_NOT_FOUND: "Commit not found",
  BLOCK_WAIT_REQUIRED: "Must wait at least 1 block to reveal",
  MINTER_ERROR: "Could not borrow FishCard minter"
}

const handleFlowTransaction = async (txFunction) => {
  try {
    const txId = await txFunction()
    console.log("Transaction submitted:", txId)
    
    // Wait for at least 2 blocks on testnet
    await new Promise(resolve => setTimeout(resolve, 6000))
    
    const result = await fcl.tx(txId).onceSealed()
    
    if (result.status === 4) {
      console.log("✅ Transaction succeeded:", txId)
      return { success: true, txId, data: result }
    } else {
      const error = parseFlowError(result.errorMessage)
      console.log("❌ Transaction failed:", error)
      return { success: false, error }
    }
  } catch (error) {
    console.error("Transaction error:", error)
    return { success: false, error: error.message }
  }
}

const parseFlowError = (errorMessage) => {
  for (const [code, message] of Object.entries(ErrorCodes)) {
    if (errorMessage.includes(message)) {
      return {
        code,
        message,
        details: errorMessage
      }
    }
  }
  return {
    code: "UNKNOWN_ERROR",
    message: errorMessage,
    details: errorMessage
  }
}
```

---

## 🚀 **Quick Start Example**

```javascript
// Complete user onboarding flow
const onboardUser = async (userAddress) => {
  console.log("🏗️ Setting up user account...")
  
  // 0. Check testnet FLOW balance
  const flowBalance = await fcl.query({
    cadence: `
      pub fun main(address: Address): UFix64 {
        return getAccount(address).balance
      }
    `,
    args: (arg, t) => [arg(userAddress, t.Address)]
  })
  
  if (flowBalance < 0.1) {
    console.warn("⚠️ Low FLOW balance. Visit https://testnet-faucet.onflow.org/")
    return
  }
  
  // 1. Setup vaults/collections
  await setupWalleyeCoinVault()
  await setupFishNFTCollection()
  
  // 2. Check user portfolio
  const portfolio = await getUserPortfolio(userAddress)
  console.log("👤 User portfolio:", portfolio)
  
  // 3. Get system data
  const system = await getSystemOverview()
  console.log("🌊 System overview:", system)
  
  return { portfolio, system }
}

// Mint first catch
const mintFirstCatch = async (catchData) => {
  console.log("🎣 Minting first catch...")
  
  const result = await mintFishAndCoins(
    catchData.angler,
    catchData.bumpShotUrl,
    catchData.heroShotUrl,
    catchData.hasRelease,
    catchData.releaseVideoUrl,
    // ... other parameters
  )
  
  if (result.success) {
    console.log("✅ Successfully minted Fish NFT + Species Coins!")
    return result
  } else {
    console.error("❌ Minting failed:", result.error)
    throw new Error(result.error)
  }
}
```

---

## 📋 **Function Reference Summary**

### **WalleyeCoin Contract**
| Function | Inputs | Returns | Purpose |
|----------|---------|---------|---------|
| `getTotalSupply()` | None | `UFix64` | Total coin supply |
| `getUserBalance(address)` | `Address` | `UFix64` | User's coin balance |
| `getSpeciesMetadata()` | None | `SpeciesMetadata` | Complete species data |
| `getBasicInfo()` | None | `{String: AnyStruct}` | Core species info |
| `getRegionalInfo(region)` | `String` | `{String: AnyStruct?}` | Regional data |
| `getAnglingInfo()` | None | `{String: AnyStruct?}` | Fishing techniques |
| `getConservationInfo()` | None | `{String: AnyStruct?}` | Conservation status |

### **FishNFT Contract** 
| Function | Inputs | Returns | Purpose |
|----------|---------|---------|---------|
| `getUserNFTIds(address)` | `Address` | `[UInt64]` | User's NFT IDs |
| `getNFTDetails(address, nftId)` | `Address, UInt64` | `FishMetadata?` | NFT details |
| `getTotalFishCaught()` | None | `UInt64` | Total fish in system |
| `checkMintingStatus(nftIds)` | `[UInt64]` | `{String: AnyStruct}` | Minting status |
| `getRegisteredSpecies()` | None | `{String: Address}` | Species registry |

### **Transactions**
| Transaction | Inputs | Purpose |
|-------------|---------|---------|
| `mintFishAndCoins` | 17 parameters | Mint NFT + auto-mint species coins |
| `transferWalleyeCoin` | `Address, UFix64` | Transfer coins |
| `transferFishNFT` | `Address, UInt64` | Transfer NFT |
| `retroactiveMintSpeciesCoins` | `Address, [UInt64]` | Process existing NFTs |

---

## 🌐 **Network-Specific Notes**

### Testnet Considerations
- Always include `--network testnet` in Flow CLI commands
- Fund accounts via Flow Testnet Faucet
- Block times are ~2-3 seconds
- Keep testnet private keys secure
- Contract addresses differ from mainnet

### Transaction Tips
- Wait for at least 2 blocks before checking transaction status
- Include proper error handling for network-specific errors
- Monitor testnet FLOW balance
- Check for proper account setup before transactions

---

**🎉 Ready to integrate with DerbyFish on Flow Testnet!**
