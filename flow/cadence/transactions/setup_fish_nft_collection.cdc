import "FishNFT"
import "NonFungibleToken"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        // Check if collection already exists
        if acct.storage.borrow<&FishNFT.Collection>(from: FishNFT.CollectionStoragePath) == nil {
            // Create and save new collection
            let collection <- FishNFT.createEmptyCollection(nftType: Type<@FishNFT.NFT>())
            acct.storage.save(<-collection, to: FishNFT.CollectionStoragePath)

            // Create public capability for the collection
            let collectionCap = acct.capabilities.storage.issue<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver}>(
                FishNFT.CollectionStoragePath
            )
            acct.capabilities.publish(collectionCap, at: FishNFT.CollectionPublicPath)
        }
    }
}