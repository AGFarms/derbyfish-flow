import "FishNFT"
import "NonFungibleToken"

transaction {
    prepare(acct: &Account) {
        if acct.storage.borrow<&FishNFT.Collection>(from: FishNFT.CollectionStoragePath) == nil {
            let collection <- FishNFT.createEmptyCollection(nftType: Type<@FishNFT.NFT>())
            acct.storage.save(<-collection, to: FishNFT.CollectionStoragePath)
        }

        let collectionCap = acct.capabilities.storage.issue<&FishNFT.Collection>(FishNFT.CollectionStoragePath)
        acct.capabilities.publish(collectionCap, at: FishNFT.CollectionPublicPath)
    }
} 