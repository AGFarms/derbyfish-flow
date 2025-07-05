import "FishNFT"
import "NonFungibleToken"

/// This transaction sets up an account to hold FishCard NFTs by
/// creating an empty collection and linking the necessary capabilities
transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        // Check if collection already exists
        if acct.storage.borrow<&FishNFT.FishCardCollection>(from: FishNFT.FishCardCollectionStoragePath) == nil {
            // Create and save new collection
            let collection <- FishNFT.createEmptyFishCardCollection()
            acct.storage.save(<-collection, to: FishNFT.FishCardCollectionStoragePath)

            // Create public capability for the collection
            let collectionCap = acct.capabilities.storage.issue<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver}>(
                FishNFT.FishCardCollectionStoragePath
            )
            acct.capabilities.publish(collectionCap, at: FishNFT.FishCardCollectionPublicPath)
        }
    }
}