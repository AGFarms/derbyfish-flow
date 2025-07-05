import "FishNFT"
import "NonFungibleToken"

// Get detailed information about a specific Fish NFT by ID
// Usage: flow scripts execute cadence/scripts/get_fish_nft_by_id.cdc <angler_address> <nft_id>

access(all) fun main(anglerAddress: Address, nftId: UInt64): {String: AnyStruct} {
    
    // Get the angler's FishNFT collection
    let collection = getAccount(anglerAddress)
        .capabilities.borrow<&FishNFT.Collection>(/public/FishNFTCollection)
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
    let nft = collection.borrowEntireNFT(id: nftId)
        ?? panic("Could not borrow Fish NFT with ID ".concat(nftId.toString()))
    
    let metadata = nft.metadata
    
    // Get private data if the caller is the owner (this will be null for others)
    let privateData = nft.getPrivateData(caller: anglerAddress)
    
    // Build the response with public metadata
    var response: {String: AnyStruct} = {
        "success": true,
        "nftId": nftId,
        "owner": anglerAddress.toString(),
        "mintedBy": nft.mintedBy.toString(),
        "metadata": {
            // Public core data
            "species": metadata.species,
            "scientificName": metadata.scientific,
            "speciesCode": metadata.speciesCode,
            "length": metadata.length,
            "weight": metadata.weight,
            "timestamp": metadata.timestamp,
            "hasRelease": metadata.hasRelease,
            "waterBody": metadata.waterBody,
            "allowFishCards": metadata.allowFishCards,
            
            // Competition data
            "competitions": metadata.competitions,
            "prizesWon": metadata.prizesWon,
            "totalPrizeValue": metadata.totalPrizeValue,
            
            // Verification data
            "verificationLevel": metadata.verificationLevel,
            "verifiedBy": metadata.verifiedBy.toString(),
            "verifiedAt": metadata.verifiedAt,
            "competitionId": metadata.competitionId,
            "recordStatus": metadata.recordStatus,
            "certificationLevel": metadata.certificationLevel,
            "qualityScore": metadata.qualityScore,
            
            // Media
            "bumpShotUrl": metadata.bumpShotUrl,
            "heroShotUrl": metadata.heroShotUrl,
            "releaseVideoUrl": metadata.releaseVideoUrl,
            "bumpHash": metadata.bumpHash,
            "heroHash": metadata.heroHash,
            "releaseHash": metadata.releaseHash
        }
    }
    
    // Add private data if available (only for owner)
    if privateData != nil {
        response["privateData"] = privateData!
    }
    
    return response
}