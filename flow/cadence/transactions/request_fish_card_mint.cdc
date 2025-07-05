import "NonFungibleToken"
import "FungibleToken"
import "FlowToken"
import "FishCardNFT"
import "FishNFT"

transaction(
    fishNFTID: UInt64,
    paymentAmount: UFix64
) {
    let fishNFTRef: &FishNFT.NFT
    let paymentVault: @FlowToken.Vault
    let minterRef: &FishCardNFT.Minter
    
    prepare(account: auth(Storage, BorrowValue) &Account) {
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
        
        // Borrow reference to the minter
        self.minterRef = account.storage.borrow<&FishCardNFT.Minter>(from: FishCardNFT.MinterStoragePath)
            ?? panic("Could not borrow FishCardNFT minter")
    }
    
    execute {
        // Request mint - this creates a receipt with VRF request
        let receipt <- self.minterRef.requestMint(
            fishNFT: self.fishNFTRef,
            payment: <-self.paymentVault
        )
        
        // Store the receipt for later reveal
        // In a real implementation, this would be stored in the user's account
        // For simplicity, we're storing it in a temporary location
        account.storage.save(<-receipt, to: StoragePath(identifier: "FishCardMintReceipt_".concat(fishNFTID.toString()))!)
        
        log("FishCard mint requested for FishNFT ID: ".concat(fishNFTID.toString()))
        log("Receipt stored - wait for reveal delay before revealing")
    }
} 