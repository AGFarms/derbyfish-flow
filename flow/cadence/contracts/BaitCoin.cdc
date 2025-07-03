import "FungibleToken"
import "MetadataViews"
import "FungibleTokenMetadataViews"
import "FUSD"

access(all) contract BaitCoin: FungibleToken {

    /// The event that is emitted when new tokens are minted
    access(all) event TokensMinted(amount: UFix64, type: String)

    /// The event that is emitted when FUSD is swapped for BaitCoin
    access(all) event FUSDSwappedForBaitCoin(fusdAmount: UFix64, baitCoinAmount: UFix64, account: Address)

    /// The event that is emitted when BaitCoin is swapped for FUSD
    access(all) event BaitCoinSwappedForFUSD(baitCoinAmount: UFix64, fusdAmount: UFix64, account: Address)

    /// Total supply of BaitCoins in existence
    access(all) var totalSupply: UFix64

    /// Storage and Public Paths
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let ReceiverPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

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
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                )
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                        // Change this to your own SVG image
                        url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                    ),
                    mediaType: "image/svg+xml"
                )
                let medias = MetadataViews.Medias([media])
                return FungibleTokenMetadataViews.FTDisplay(
                    // Change these to represent your own token
                    name: "BaitCoin",
                    symbol: "BAIT",
                    description: "BaitCoin is the primary currency for the DerbyFish ecosystem.",
                    externalURL: MetadataViews.ExternalURL("https://derbyfish.example.com"),
                    logos: medias,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/derbyfish")
                    }
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: self.VaultStoragePath,
                    receiverPath: self.VaultPublicPath,
                    metadataPath: self.VaultPublicPath,
                    receiverLinkedType: Type<&BaitCoin.Vault>(),
                    metadataLinkedType: Type<&BaitCoin.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-BaitCoin.createEmptyVault(vaultType: Type<@BaitCoin.Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: BaitCoin.totalSupply
                )
        }
        return nil
    }

    access(all) resource Vault: FungibleToken.Vault {

        /// The total balance of this vault
        access(all) var balance: UFix64

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        /// Called when a fungible token is burned via the `Burner.burn()` method
        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                BaitCoin.totalSupply = BaitCoin.totalSupply - self.balance
            }
            self.balance = 0.0
        }

        access(all) view fun getViews(): [Type] {
            return BaitCoin.getContractViews(resourceType: nil)
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return BaitCoin.resolveContractView(resourceType: nil, viewType: view)
        }

        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[self.getType()] = true
            return supportedTypes
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.getSupportedVaultTypes()[type] ?? false
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @BaitCoin.Vault {
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }

        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @BaitCoin.Vault
            self.balance = self.balance + vault.balance
            vault.balance = 0.0
            destroy vault
        }

        access(all) fun createEmptyVault(): @BaitCoin.Vault {
            return <-create Vault(balance: 0.0)
        }
    }

    access(all) resource Minter {
        /// Internal minting function - only accessible within this resource
        access(self) fun mintTokensInternal(amount: UFix64): @BaitCoin.Vault {
            BaitCoin.totalSupply = BaitCoin.totalSupply + amount
            let vault <-create Vault(balance: amount)
            emit TokensMinted(amount: amount, type: vault.getType().identifier)
            return <-vault
        }
    }

    access(all) fun createEmptyVault(vaultType: Type): @BaitCoin.Vault {
        return <- create Vault(balance: 0.0)
    }

    /// Get the FUSD balance stored in the contract
    access(all) fun getContractFUSDBalance(): UFix64 {
        let fusdVault = self.account.storage.borrow<&FUSD.Vault>(from: /storage/BaitCoinFUSDVault)
            ?? panic("Could not borrow contract FUSD vault")
        return fusdVault.balance
    }

    /// Public swap function: FUSD for BaitCoin
    access(all) fun swapFUSDForBaitCoin(from: @FUSD.Vault, recipient: Address) {
        let fusdAmount = from.balance
        
        // Get reference to contract's FUSD vault and deposit received FUSD
        let contractFUSDVault = self.account.storage.borrow<&FUSD.Vault>(from: /storage/BaitCoinFUSDVault)
            ?? panic("Could not borrow reference to contract's FUSD vault")
        contractFUSDVault.deposit(from: <-from)

        // Mint equivalent BaitCoin internally
        self.totalSupply = self.totalSupply + fusdAmount
        let newBaitCoin <- create Vault(balance: fusdAmount)
        emit TokensMinted(amount: fusdAmount, type: newBaitCoin.getType().identifier)
        
        // Get recipient's BaitCoin receiver
        let recipientReceiver = getAccount(recipient).capabilities.borrow<&{FungibleToken.Receiver}>(self.VaultPublicPath)
            ?? panic("Could not borrow receiver capability for recipient")
        
        // Deposit BaitCoin to recipient
        recipientReceiver.deposit(from: <-newBaitCoin)
        
        emit FUSDSwappedForBaitCoin(fusdAmount: fusdAmount, baitCoinAmount: fusdAmount, account: recipient)
    }

    /// Public swap function: BaitCoin for FUSD
    access(all) fun swapBaitCoinForFUSD(from: @BaitCoin.Vault, recipient: Address) {
        let baitCoinAmount = from.balance
        
        // Burn the received BaitCoin
        self.totalSupply = self.totalSupply - baitCoinAmount
        destroy from
        
        // Get reference to contract's FUSD vault and withdraw equivalent FUSD
        let contractFUSDVault = self.account.storage.borrow<auth(FungibleToken.Withdraw) &FUSD.Vault>(from: /storage/BaitCoinFUSDVault)
            ?? panic("Could not borrow reference to contract's FUSD vault")
        
        let fusdToSend <- contractFUSDVault.withdraw(amount: baitCoinAmount)
        
        // Get recipient's FUSD receiver
        let recipientReceiver = getAccount(recipient).capabilities.borrow<&{FungibleToken.Receiver}>(/public/fusdReceiver)
            ?? panic("Could not borrow FUSD receiver capability for recipient")
        
        // Deposit FUSD to recipient
        recipientReceiver.deposit(from: <-fusdToSend)
        
        emit BaitCoinSwappedForFUSD(baitCoinAmount: baitCoinAmount, fusdAmount: baitCoinAmount, account: recipient)
    }

    init() {
        self.totalSupply = 0.0

        self.VaultStoragePath = /storage/BaitCoinVault
        self.VaultPublicPath = /public/BaitCoinVault
        self.ReceiverPublicPath = /public/BaitCoinReceiver
        self.MinterStoragePath = /storage/BaitCoinMinter

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create Vault(balance: self.totalSupply)
        emit TokensMinted(amount: vault.balance, type: vault.getType().identifier)
        self.account.storage.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that exposes
        // the `deposit` method and getAcceptedTypes method through the `Receiver` interface
        // and the `balance` method through the `Balance` interface
        //
        let BaitCoinCap = self.account.capabilities.storage.issue<&BaitCoin.Vault>(self.VaultStoragePath)
        self.account.capabilities.publish(BaitCoinCap, at: self.VaultPublicPath)

        // Create a FUSD vault for the contract to store received FUSD
        let fusdVault <- FUSD.createEmptyVault(vaultType: Type<@FUSD.Vault>())
        self.account.storage.save(<-fusdVault, to: /storage/BaitCoinFUSDVault)

        let minter <- create Minter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
    }
}
