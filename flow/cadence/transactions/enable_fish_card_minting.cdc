import "FishNFT"

transaction(fishNFTId: UInt64) {
    let fishNFTRef: &FishNFT.NFT
    
    prepare(acct: auth(Storage, BorrowValue) &Account) {
        // Borrow reference to the FishNFT collection
        let fishNFTCollection = acct.storage.borrow<&FishNFT.Collection>(from: FishNFT.CollectionStoragePath)
            ?? panic("Could not borrow FishNFT collection from account")
            
        // Borrow reference to the specific FishNFT
        self.fishNFTRef = fishNFTCollection.borrowEntireNFT(id: fishNFTId)
            ?? panic("Could not borrow FishNFT with ID: ".concat(fishNFTId.toString()))
    }
    
    execute {
        // Enable fish card minting for this NFT
        self.fishNFTRef.enableFishCards()
        
        log("Fish card minting enabled for FishNFT ID: ".concat(fishNFTId.toString()))
    }
}