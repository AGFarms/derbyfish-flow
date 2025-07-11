import "NonFungibleToken"
import "FungibleToken"
import "FlowToken"
import "FishCardNFT"
import "FishNFT"

transaction(
    fishNFTID: UInt64,
    recipientAddress: Address,
    paymentAmount: UFix64
) {
    let fishNFTRef: &FishNFT.NFT
    let paymentVault: @FlowToken.Vault
    let minterRef: &FishCardNFT.Minter
    let recipientCollection: &FishCardNFT.Collection
    
    prepare(account: auth(Storage, BorrowValue, Withdraw) &Account) {
        // Borrow reference to the FishNFT collection
        let fishNFTCollection = account.storage.borrow<&FishNFT.Collection>(from: FishNFT.CollectionStoragePath)
            ?? panic("Could not borrow FishNFT collection")
            
        // Borrow reference to the specific FishNFT
        self.fishNFTRef = fishNFTCollection.borrowEntireNFT(id: fishNFTID)
            ?? panic("Could not borrow FishNFT with ID: ".concat(fishNFTID.toString()))
            
        // Verify the FishNFT allows fish card minting
        if !self.fishNFTRef.canMintFishCards() {
            panic("This FishNFT does not allow fish card minting")
        }
        
        // Borrow reference to the payment vault
        let paymentVaultRef = account.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")
            
        // Withdraw payment
        self.paymentVault <- paymentVaultRef.withdraw(amount: paymentAmount) as! @FlowToken.Vault
        
        // Borrow reference to the minter from the contract account
        let contractAccount = getAccount(0xf8d6e0586b0a20c7) // emulator-account
        self.minterRef = contractAccount.storage.borrow<&FishCardNFT.Minter>(from: FishCardNFT.MinterStoragePath)
            ?? panic("Could not borrow FishCardNFT minter from contract account")
            
        // Get reference to recipient's collection
        let recipientAccount = getAccount(recipientAddress)
        self.recipientCollection = recipientAccount.capabilities.borrow<&FishCardNFT.Collection>(FishCardNFT.CollectionPublicPath)
            ?? panic("Could not borrow recipient's FishCardNFT collection")
    }
    
    execute {
        // Mint the card directly (single-phase minting)
        let fishCard <- self.minterRef.mintCard(
            fishNFT: self.fishNFTRef,
            recipient: recipientAddress,
            payment: <-self.paymentVault
        )
        
        // Deposit the new FishCard into the recipient's collection
        self.recipientCollection.deposit(token: <-fishCard)
        
        log("FishCard NFT minted successfully for FishNFT ID: ".concat(fishNFTID.toString()))
    }
}