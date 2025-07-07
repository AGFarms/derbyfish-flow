import "FishNFT"
import "NonFungibleToken"

// Get public information about a Fish NFT by ID
// Note: This requires finding the owner first since NFTs are in individual collections
// In practice, you'd use off-chain event indexing to map NFT ID -> owner address
// Usage: flow scripts execute cadence/scripts/get_fish_nft_by_id_no_addr.cdc <nft_id> [optional_owner_hint]

access(all) fun main(nftId: UInt64, ownerHint: Address?): {String: AnyStruct} {
    
    // Get the total number of fish NFTs that have been minted
    let totalFish = FishNFT.getTotalFishCaught()
    
    // Check if the NFT ID is in the valid range
    if nftId < 1 || nftId > totalFish {
        return {
            "success": false,
            "error": "Invalid NFT ID: ".concat(nftId.toString()),
            "validRange": "1 to ".concat(totalFish.toString()),
            "totalMinted": totalFish
        }
    }
    
    // If owner hint is provided, try to get the NFT data
    if ownerHint != nil {
        return tryGetNFTData(nftId: nftId, ownerAddress: ownerHint!)
    }
    
    // Without owner address, we cannot access the NFT directly in a script
    // In a real app, you'd use Flow's event indexing to find the owner
    return {
        "success": false,
        "nftId": nftId,
        "status": "NFT ID exists but owner unknown",
        "totalMinted": totalFish,
        "limitation": "Cannot access NFT data without owner address",
        "solution": "Use Flow's event indexing to find owner from FishMinted events",
        "eventToQuery": "FishMinted events contain nft_id and recipient address",
        "workaround": "Call this script again with ownerHint parameter if you know the owner"
    }
}

// Helper function to get NFT data from a specific owner
access(all) fun tryGetNFTData(nftId: UInt64, ownerAddress: Address): {String: AnyStruct} {
    // Try to get the owner's FishNFT collection
    let collection = getAccount(ownerAddress)
        .capabilities.borrow<&FishNFT.Collection>(/public/FishNFTCollection)
    
    if collection == nil {
        return {
            "success": false,
            "error": "Owner does not have a FishNFT collection",
            "ownerAddress": ownerAddress.toString()
        }
    }
    
    // Check if this collection contains the NFT
    if !collection!.getIDs().contains(nftId) {
        return {
            "success": false,
            "error": "NFT not found in this owner's collection",
            "nftId": nftId,
            "ownerAddress": ownerAddress.toString(),
            "ownedNFTs": collection!.getIDs()
        }
    }
    
    // Get the NFT and return public data
    let nft = collection!.borrowEntireNFT(id: nftId)!
    let metadata = nft.metadata
    
    return {
        "success": true,
        "nftId": nftId,
        "ownerAddress": ownerAddress.toString(),
        "publicData": {
            // Core public data
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
            
            // Public media
            "bumpShotUrl": metadata.bumpShotUrl,
            "heroShotUrl": metadata.heroShotUrl,
            "releaseVideoUrl": metadata.releaseVideoUrl,
            "bumpHash": metadata.bumpHash,
            "heroHash": metadata.heroHash,
            "releaseHash": metadata.releaseHash
        },
        "note": "Private location and angler data not accessible without owner authorization"
    }
}