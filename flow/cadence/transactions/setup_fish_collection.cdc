import "Fish"
import "NonFungibleToken"

transaction {

    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {

        // Return early if the account already has a collection
        if signer.storage.borrow<&Fish.Collection>(from: Fish.CollectionStoragePath) != nil {
            return
        }

        // Create a new empty collection
        let collection <- Fish.createEmptyCollection(nftType: Type<@Fish.NFT>())

        // save it to the account
        signer.storage.save(<-collection, to: Fish.CollectionStoragePath)

        let collectionCap = signer.capabilities.storage.issue<&Fish.Collection>(Fish.CollectionStoragePath)
        signer.capabilities.publish(collectionCap, at: Fish.CollectionPublicPath)
    }
}
