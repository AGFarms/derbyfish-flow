import "FungibleToken"
import "FungibleTokenMetadataViews"
import "MetadataViews"
import "ViewResolver"
// Note: USDF is an EVM bridged token at address 0x1e4aa0b87d10b141
// We'll interact with it through the FungibleToken interface

access(all) contract BaitCoin: FungibleToken {

    // Token metadata
    access(all) let name: String
    access(all) let symbol: String
    access(all) let decimals: UInt8
    access(all) var logoUrl: String
    access(all) var metadata: String
    
    // Total supply tracking
    access(all) var totalSupply: UFix64

    // Storage paths
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let ReceiverPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let USDCVaultStoragePath: StoragePath

    // Events
    access(all) event TokensInitialized(initialSupply: UFix64)
    access(all) event USDFToBaitSwap(user: Address, usdfAmount: UFix64, baitAmount: UFix64)
    access(all) event BaitToUSDFSwap(user: Address, baitAmount: UFix64, usdfAmount: UFix64)
    access(all) event LogoUrlUpdated(newLogoUrl: String)
    access(all) event MetadataUpdated(newMetadata: String)
    
    // Minter resource for minting tokens
    access(all) resource Minter {
        access(all) fun mintTokens(amount: UFix64): @{FungibleToken.Vault} {
            BaitCoin.totalSupply = BaitCoin.totalSupply + amount
            return <-create Vault(balance: amount)
        }
    }

    // Admin resource for minting/burning and admin management
    access(all) resource Admin {
        access(all) fun mintBait(amount: UFix64, recipient: Address) {
            BaitCoin.totalSupply = BaitCoin.totalSupply + amount
            
            let recipientAccount = getAccount(recipient)
            let receiver = recipientAccount.capabilities.get<&{FungibleToken.Receiver}>(BaitCoin.ReceiverPublicPath)
                .borrow() ?? panic("Could not borrow receiver reference")
            
            let tempVault <- create Vault(balance: amount)
            receiver.deposit(from: <-tempVault)
        }
        
        access(all) fun burnBait(amount: UFix64, from: Address) {
            // Note: This function requires the transaction to have proper authorization
            // to withdraw from the target account. The actual burning should be done
            // in the transaction that calls this function.
            panic("This function should be called from a transaction with proper authorization")
        }
        
        access(all) fun setLogoUrl(newLogoUrl: String) {
            BaitCoin.logoUrl = newLogoUrl
            emit LogoUrlUpdated(newLogoUrl: newLogoUrl)
        }
        
        access(all) fun setMetadata(newMetadata: String) {
            BaitCoin.metadata = newMetadata
            emit MetadataUpdated(newMetadata: newMetadata)
        }
    }
    
    // Admin management resource
    access(all) resource AdminManager {
        // Note: These functions require proper authorization and should be called from transactions
        // that have the necessary capabilities
        access(all) fun addAdmin(adminAddress: Address, adminCapability: Capability<&BaitCoin.Admin>) {
            // This function should be called from a transaction with proper authorization
            // The transaction signer must have the capability to publish at the target account
            panic("This function should be called from a transaction with proper authorization")
        }
        
        access(all) fun removeAdmin(adminAddress: Address) {
            // This function should be called from a transaction with proper authorization
            // The transaction signer must have the capability to unpublish at the target account
            panic("This function should be called from a transaction with proper authorization")
        }
    }
    
    // Main vault resource
    access(all) resource Vault: FungibleToken.Vault, ViewResolver.Resolver {
        access(all) var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<FungibleTokenMetadataViews.FTDisplay>(),
                Type<FungibleTokenMetadataViews.FTVaultData>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<FungibleTokenMetadataViews.FTDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: BaitCoin.logoUrl),
                        mediaType: "image/png"
                    )
                    return FungibleTokenMetadataViews.FTDisplay(
                        name: BaitCoin.name,
                        symbol: BaitCoin.symbol,
                        description: BaitCoin.metadata,
                        externalURL: MetadataViews.ExternalURL("https://derby.fish"),
                        logos: MetadataViews.Medias([media]),
                        socials: {
                            "website": MetadataViews.ExternalURL("https://derby.fish/bait-coin-logo.png"),
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/derby_fish")
                        }
                    )
                case Type<FungibleTokenMetadataViews.FTVaultData>():
                    return FungibleTokenMetadataViews.FTVaultData(
                        storagePath: BaitCoin.VaultStoragePath,
                        receiverPath: BaitCoin.ReceiverPublicPath,
                        metadataPath: BaitCoin.VaultPublicPath,
                        receiverLinkedType: Type<&BaitCoin.Vault>(),
                        metadataLinkedType: Type<&BaitCoin.Vault>(),
                        createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                            return <-BaitCoin.createEmptyVault(vaultType: Type<@BaitCoin.Vault>())
                        })
                    )
            }
            return nil
        }

        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {Type<@BaitCoin.Vault>(): true}
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return type == Type<@BaitCoin.Vault>()
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @BaitCoin.Vault {
            pre {
                amount <= self.balance: "Amount withdrawn must be less than or equal to the balance of the Vault"
            }
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }

        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @BaitCoin.Vault
            self.balance = self.balance + vault.balance
            vault.balance = 0.0
            destroy vault
        }

        access(all) fun createEmptyVault(): @{FungibleToken.Vault} {
            return <-create Vault(balance: 0.0)
        }

        access(all) fun createEmptyVaultWithType(vaultType: Type): @{FungibleToken.Vault} {
        pre {
            vaultType == Type<@BaitCoin.Vault>(): "Vault type mismatch"
        }
        return <-create Vault(balance: 0.0)
    }


    }

    access(all) fun swapUSDFToBait(usdfVault: @{FungibleToken.Vault}, userAddress: Address): @{FungibleToken.Vault} {
        let usdfAmount = (usdfVault).balance
        
        if usdfAmount <= 0.0 {
            panic("Amount must be greater than zero")
        }
        
        // Get the user's BAIT vault
        let userAccount = getAccount(userAddress)
        log("Attempting to get BAIT receiver for user: ".concat(userAddress.toString()))
        log("Looking for receiver at path: ".concat(BaitCoin.ReceiverPublicPath.toString()))
        
        let receiverCapability = userAccount.capabilities.get<&{FungibleToken.Receiver}>(BaitCoin.ReceiverPublicPath)
        if receiverCapability != nil {
            log("Receiver capability found: true")
        } else {
            log("Receiver capability found: false")
        }
        
        let baitReceiver = receiverCapability
            .borrow() ?? panic("Could not borrow BAIT receiver reference. Please run setup_vault.cdc first to create your BAIT vault.")
        
        // Deposit USDF to contract's vault for future BAIT to USDF swaps
        // Store the USDF in the original EVM vault path
        let contractUSDFVault = BaitCoin.account.storage.borrow<&{FungibleToken.Vault}>(from: /storage/EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabedVault)
        if contractUSDFVault == nil {
            // Create the USDF vault if it doesn't exist by saving the incoming vault
            BaitCoin.account.storage.save(<-usdfVault, to: /storage/EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabedVault)
        } else {
            // Deposit to existing vault
            contractUSDFVault!.deposit(from: <-usdfVault)
        }
        
        // Mint equivalent amount of BAIT
        BaitCoin.totalSupply = BaitCoin.totalSupply + usdfAmount
        let baitVault <- create Vault(balance: usdfAmount)
        
        // Send BAIT to user
        baitReceiver.deposit(from: <-baitVault)
        
        emit USDFToBaitSwap(user: userAddress, usdfAmount: usdfAmount, baitAmount: usdfAmount)
        
        // Return empty vault for transaction completion
        return <-create Vault(balance: 0.0)
    }
    
    access(all) fun swapBaitToUSDF(baitVault: @{FungibleToken.Vault}, userAddress: Address): @{FungibleToken.Vault} {
        let baitAmount = (baitVault).balance
        
        if baitAmount <= 0.0 {
            panic("Amount must be greater than zero")
        }
        
        // Get the user's USDF vault
        let userAccount = getAccount(userAddress)
        let usdfReceiverCapability = userAccount.capabilities.get<&{FungibleToken.Receiver}>(/public/usdfReceiver)
        let usdfReceiver = usdfReceiverCapability
            .borrow() ?? panic("Could not borrow USDF receiver reference. Please run createAllVault.cdc first to create your USDF vault.")
        
        // Burn the BAIT tokens (reduce total supply)
        BaitCoin.totalSupply = BaitCoin.totalSupply - baitAmount
        destroy baitVault
        
        // Withdraw equivalent USDF from contract's vault
        let contractUSDFVault = BaitCoin.account.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(from: /storage/EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabedVault)
            ?? panic("Could not borrow contract USDF vault")
        
        let usdfVault <- contractUSDFVault.withdraw(amount: baitAmount)
        
        // Send USDF to user
        usdfReceiver.deposit(from: <-usdfVault)
        
        emit BaitToUSDFSwap(user: userAddress, baitAmount: baitAmount, usdfAmount: baitAmount)
        
        // Return empty vault for transaction completion
        return <-create Vault(balance: 0.0)
    }
    
    
    access(all) fun getTokenInfo(): {String: String} {
        return {
            "name": self.name,
            "symbol": self.symbol,
            "logoUrl": self.logoUrl,
            "metadata": self.metadata,
            "totalSupply": self.totalSupply.toString(),
            "decimals": self.decimals.toString()
        }
    }
    
    // FungibleTokenMetadataViews.Resolver implementation
    access(all) fun getViews(): [Type] {
        return [Type<FungibleTokenMetadataViews.FTView>()]
    }
    
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>(),
            Type<FungibleTokenMetadataViews.TotalSupply>()
        ]
    }
    
    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(url: self.logoUrl),
                    mediaType: "image/png"
                )
                return FungibleTokenMetadataViews.FTDisplay(
                    name: self.name,
                    symbol: self.symbol,
                    description: self.metadata,
                    externalURL: MetadataViews.ExternalURL("https://derby.fish"),
                    logos: MetadataViews.Medias([media]),
                    socials: {
                        "website": MetadataViews.ExternalURL("https://derby.fish/bait-coin-logo.png"),
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/derby_fish")
                    }
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: self.VaultStoragePath,
                    receiverPath: self.ReceiverPublicPath,
                    metadataPath: self.VaultPublicPath,
                    receiverLinkedType: Type<&BaitCoin.Vault>(),
                    metadataLinkedType: Type<&BaitCoin.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-BaitCoin.createEmptyVault(vaultType: Type<@BaitCoin.Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(totalSupply: self.totalSupply)
        }
        return nil
    }
    
    access(all) fun getSupportedVaultTypes(): [Type] {
        return [Type<@BaitCoin.Vault>()]
    }

    access(all) fun createEmptyVault(vaultType: Type): @BaitCoin.Vault {
        return <-create Vault(balance: 0.0)
    }
    
    // Admin function to burn tokens and reduce total supply
    access(all) fun burnTokens(amount: UFix64) {
        self.totalSupply = self.totalSupply - amount
    }
    
    // Admin function to withdraw USDF from contract
    access(all) fun withdrawUSDF(amount: UFix64, recipient: Address) {
        let contractUSDFVault = BaitCoin.account.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(from: /storage/EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabedVault)
            ?? panic("Could not borrow contract USDF vault")
        
        let usdfVault <- contractUSDFVault.withdraw(amount: amount)
        
        let recipientAccount = getAccount(recipient)
        let receiver = recipientAccount.capabilities.get<&{FungibleToken.Receiver}>(/public/usdfReceiver)
            .borrow() ?? panic("Could not borrow recipient's USDF receiver reference")
        
        receiver.deposit(from: <-usdfVault)
    }
    
    // Initialize the contract
    init() {
        self.name = "BAIT Coin"
        self.symbol = "BAIT"
        self.decimals = 8
        self.logoUrl = "https://derby.fish/bait-coin-logo.png"
        self.metadata = "BAIT COIN - A 1:1 pegged USDF token for the DerbyFish (https://derby.fish) ecosystem."
        self.totalSupply = 0.0

        // Set storage paths
        self.VaultStoragePath = /storage/baitCoinVault
        self.VaultPublicPath = /public/baitCoinVault
        self.ReceiverPublicPath = /public/baitCoinReceiver
        self.MinterStoragePath = /storage/baitCoinMinter
        self.USDCVaultStoragePath = /storage/baitCoinUSDCVault

        // Create and store the minter resource
        let minter <- create Minter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)

        // Create and store the admin resource
        let admin <- create Admin()
        self.account.storage.save(<-admin, to: /storage/baitCoinAdmin)
        let adminCapability = self.account.capabilities.storage.issue<&BaitCoin.Admin>(/storage/baitCoinAdmin)
        self.account.capabilities.publish(adminCapability, at: /public/baitCoinAdmin)
        
        // Create and store the admin manager resource
        let adminManager <- create AdminManager()
        self.account.storage.save(<-adminManager, to: /storage/baitCoinAdminManager)
        let adminManagerCapability = self.account.capabilities.storage.issue<&BaitCoin.AdminManager>(/storage/baitCoinAdminManager)
        self.account.capabilities.publish(adminManagerCapability, at: /public/baitCoinAdminManager)
        
        // Note: USDF vault will be created when first USDF tokens are received
        // The vault will be created dynamically in the swap functions
        
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}