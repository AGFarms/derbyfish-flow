import "FishNFT"
import "NonFungibleToken"

/// Returns all FishCard IDs owned by the specified address
access(all) fun main(address: Address): [UInt64] {
    let account = getAccount(address)
    
    let collectionRef = account.capabilities
        .borrow<&{NonFungibleToken.CollectionPublic}>(FishNFT.FishCardCollectionPublicPath)
        ?? panic("Could not borrow FishCard collection")
    
    return collectionRef.getIDs()
}