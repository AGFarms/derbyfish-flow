import "NonFungibleToken"
import "FishCardNFT"
import "FishNFT"

transaction(
    fishNFTID: UInt64,
    recipientAddress: Address
) {
    let fishNFTRef: &FishNFT.NFT
    let minterRef: &FishCardNFT.Minter
    let recipientCollection: &FishCardNFT.Collection
    let acct: auth(Storage, BorrowValue) &Account
    
    prepare(acct: auth(Storage, BorrowValue) &Account) {
        self.acct = acct
        // Borrow reference to the FishNFT collection
        let fishNFTCollection = acct.storage.borrow<&FishNFT.Collection>(from: FishNFT.CollectionStoragePath)
            ?? panic("Could not borrow FishNFT collection")
            
        // Borrow reference to the specific FishNFT
        self.fishNFTRef = fishNFTCollection.borrowEntireNFT(id: fishNFTID)
            ?? panic("Could not borrow FishNFT with ID: ".concat(fishNFTID.toString()))
        
        // Borrow reference to the minter
        self.minterRef = acct.storage.borrow<&FishCardNFT.Minter>(from: FishCardNFT.MinterStoragePath)
            ?? panic("Could not borrow FishCardNFT minter")
            
        // Get reference to recipient's collection
        let recipientAccount = getAccount(recipientAddress)
        self.recipientCollection = recipientAccount.capabilities.borrow<&FishCardNFT.Collection>(FishCardNFT.CollectionPublicPath)
            ?? panic("Could not borrow recipient's FishCardNFT collection")
    }
    
    execute {
        // Load the receipt from storage
        let receiptStoragePath = StoragePath(identifier: "FishCardMintReceipt_".concat(fishNFTID.toString()))!
        let receipt <- self.acct.storage.load<@FishCardNFT.Receipt>(from: receiptStoragePath)
            ?? panic("Could not load mint receipt - make sure you have requested a mint first")
        
        // Get the VRF request from the receipt
        let vrfRequest <- receipt.popRequest()
        
        // Clean up the receipt
        destroy receipt
        
        // Reveal and mint the card
        let fishCard <- self.minterRef.revealAndMint(
            request: <-vrfRequest,
            fishNFT: self.fishNFTRef,
            recipient: recipientAddress
        )
        
        // Deposit the new FishCard into the recipient's collection
        self.recipientCollection.deposit(token: <-fishCard)
        
        log("FishCard NFT revealed and minted successfully for FishNFT ID: ".concat(fishNFTID.toString()))
    }
} 