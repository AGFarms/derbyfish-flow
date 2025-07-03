import "FishNFT"
import "NonFungibleToken"

access(all) fun main(account: Address): [UInt64] {
    let collection = getAccount(account)
        .capabilities.borrow<&{NonFungibleToken.Collection}>(/public/FishNFTCollection)
        ?? panic("Could not borrow FishNFT collection from account")
    return collection.getIDs()
}