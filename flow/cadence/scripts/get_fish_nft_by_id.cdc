import "FishNFT"
import "NonFungibleToken"
import "MetadataViews"

// Get detailed information about a specific Fish NFT by ID
// Usage: flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc <angler_address> <nft_id>

access(all) fun main(anglerAddress: Address, nftId: UInt64): {String: AnyStruct} {
    
    // Get the angler's FishNFT collection
    let collection = getAccount(anglerAddress)
        .capabilities.borrow<&{NonFungibleToken.Collection}>(/public/FishNFTCollection)
        ?? panic("Could not borrow FishNFT collection from angler account")
    
    // Check if the NFT exists
    if !collection.getIDs().contains(nftId) {
        return {
            "success": false,
            "error": "NFT with ID ".concat(nftId.toString()).concat(" not found in collection"),
            "availableIds": collection.getIDs()
        }
    }
    
    // Borrow the specific NFT
    let nft = collection.borrowNFT(nftId) as! &FishNFT.NFT
    let metadata = nft.metadata
    
    // Return comprehensive NFT information
    return {
        "success": true,
        "nftId": nftId,
        "owner": anglerAddress.toString(),
        "mintedBy": nft.mintedBy.toString(),
        "mintedAt": nft.mintedAt,
        "metadata": {
            "species": metadata.species,
            "scientificName": metadata.scientific,
            "speciesCode": metadata.speciesCode,
            "length": metadata.length,
            "latitude": metadata.latitude,
            "longitude": metadata.longitude,
            "location": metadata.location,
            "gear": metadata.gear,
            "timestamp": metadata.timestamp,
            "hasRelease": metadata.hasRelease,
            "bumpShotUrl": metadata.bumpShotUrl,
            "heroShotUrl": metadata.heroShotUrl,
            "releaseVideoUrl": metadata.releaseVideoUrl,
            "bumpHash": metadata.bumpHash,
            "heroHash": metadata.heroHash,
            "releaseHash": metadata.releaseHash
        }
    }
}