import "FishNFT"
import "WalleyeCoin"
import "NonFungibleToken"
import "FungibleToken"

transaction(
    recipient: Address,
    fishNFTId: UInt64
) {
    let recipientAccount: &Account
    let walleyeCoinAddress: Address

    prepare(acct: auth(Storage) &Account) {
        self.recipientAccount = getAccount(recipient)
        self.walleyeCoinAddress = 0xf8d6e0586b0a20c7
    }

    execute {
        // Get recipient's Fish NFT collection with proper capabilities
        let recipientCollection = self.recipientAccount
            .capabilities.borrow<&FishNFT.Collection>(FishNFT.CollectionPublicPath)
            ?? panic("Could not borrow recipient NFT collection")
        
        // Get the Fish NFT to extract species data
        let fishNFT = recipientCollection.borrowEntireNFT(id: fishNFTId)
            ?? panic("Could not borrow Fish NFT with ID ".concat(fishNFTId.toString()))
        
        let speciesCode = fishNFT.getSpeciesCode()
        
        // Only process Walleye fish for WalleyeCoin
        if speciesCode != "SANDER_VITREUS" {
            panic("Fish NFT #".concat(fishNFTId.toString()).concat(" is not a Walleye (").concat(speciesCode).concat(") - cannot mint WalleyeCoin"))
        }
        
        // Get WalleyeCoin coordinator
        let walleyeCoinAccount = getAccount(self.walleyeCoinAddress)
        let coordinatorRef = walleyeCoinAccount.capabilities.borrow<&WalleyeCoin.FishDEXCoordinator>(
            WalleyeCoin.FishDEXCoordinatorPublicPath
        ) ?? panic("Could not borrow WalleyeCoin coordinator")
        
        // Get recipient's species coin vault
        let anglerVaultRef = self.recipientAccount.capabilities.borrow<&{FungibleToken.Receiver}>(
            WalleyeCoin.VaultPublicPath
        ) ?? panic("Could not borrow recipient species coin vault - make sure to run setup_walleye_coin_account.cdc first")
        
        // Prepare fish data for the species coin
        let fishData: {String: AnyStruct} = {
            "nftId": fishNFTId,
            "speciesCode": speciesCode,
            "angler": recipient
        }
        
        // Call redeemCatchNFT to mint 1.0 species coins
        // Note: The species coin contract handles its own tracking of which NFTs have been used
        let speciesVault <- coordinatorRef.redeemCatchNFT(
            fishData: fishData,
            angler: recipient
        )
        
        // Deposit species coins to recipient
        anglerVaultRef.deposit(from: <- speciesVault)
        
        log("✅ Species coins minted successfully!")
        log("Fish NFT ID: ".concat(fishNFTId.toString()))
        log("Species: ".concat(speciesCode))
        log("Amount: 1.0 coins")
        log("Recipient: ".concat(recipient.toString()))
        log("Note: Species coin contract handles duplicate prevention")
    }
}