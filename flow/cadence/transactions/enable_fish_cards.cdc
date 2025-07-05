import "FishNFT"

/// This transaction enables FishCard minting for a specific Fish NFT
/// The caller must be the owner of the Fish NFT
transaction(fishNFTId: UInt64) {
    prepare(acct: auth(Storage, BorrowValue) &Account) {
        // Get the owner's collection reference
        let collectionRef = acct.storage.borrow<&FishNFT.Collection>(from: FishNFT.CollectionStoragePath)
            ?? panic("Could not borrow Fish NFT collection")

        // Get the NFT reference
        let nft = collectionRef.borrowEntireNFT(id: fishNFTId)
            ?? panic("Could not borrow Fish NFT with ID: ".concat(fishNFTId.toString()))

        // Enable FishCard minting
        nft.enableFishCards()
    }
} 