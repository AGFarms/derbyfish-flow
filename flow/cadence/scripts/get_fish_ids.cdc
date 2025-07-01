import "NonFungibleToken"
import "Fish"

access(all) fun main(address: Address): [UInt64] {
    let account = getAccount(address)

    let collectionRef = account.capabilities.borrow<&{NonFungibleToken.Collection}>(
            Fish.CollectionPublicPath
    ) ?? panic("The account ".concat(address.toString()).concat(" does not have a NonFungibleToken Collection at ")
                .concat(Fish.CollectionPublicPath.toString())
                .concat(". The account must initialize their account with this collection first!"))

    return collectionRef.getIDs()
}
