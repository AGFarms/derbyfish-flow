import "FishNFT"
import "NonFungibleToken"

/// Returns detailed information about a specific FishCard
access(all) fun main(address: Address, id: UInt64): {String: AnyStruct} {
    // Get the FishCard collection
    let collection = getAccount(address)
        .capabilities.borrow<&FishNFT.FishCardCollection>(FishNFT.FishCardCollectionPublicPath)
        ?? panic("Could not borrow FishCard collection")
    
    // Check if the card exists
    if !collection.getIDs().contains(id) {
        return {
            "success": false,
            "error": "FishCard with ID ".concat(id.toString()).concat(" not found in collection"),
            "availableIds": collection.getIDs()
        }
    }
    
    // Borrow the specific FishCard
    let fishCard = collection.borrowFishCard(id: id)
        ?? panic("Could not borrow FishCard with ID: ".concat(id.toString()))
    
    return {
        "success": true,
        "id": fishCard.id,
        "fishNFTId": fishCard.getFishNFTId(),
        "species": fishCard.getSpecies(),
        "rarity": fishCard.getRarity(),
        "revealedFields": fishCard.getRevealedFields()
    }
}