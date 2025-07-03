import "FishNFT"
import "NonFungibleToken"
import "MetadataViews"

// Comprehensive script to test Walleye NFT functionality
// Usage: flow scripts execute cadence/scripts/test_walleye_nft.cdc <angler_address>

access(all) fun main(anglerAddress: Address): {String: AnyStruct} {
    
    // Get the angler's FishNFT collection
    let collection = getAccount(anglerAddress)
        .capabilities.borrow<&{NonFungibleToken.Collection}>(/public/FishNFTCollection)
        ?? panic("Could not borrow FishNFT collection from angler account")
    
    let fishIds = collection.getIDs()
    
    var walleyeCount = 0
    var totalFish = fishIds.length
    var walleyeNFTs: [{String: AnyStruct}] = []
    
    // Examine each NFT to find Walleye catches
    for fishId in fishIds {
        let nft = collection.borrowNFT(id: fishId) as! &FishNFT.NFT
        let metadata = nft.metadata
        
        // Check if this is a Walleye
        if metadata.species == "Walleye" || metadata.scientific == "Sander vitreus" {
            walleyeCount = walleyeCount + 1
            
            // Collect detailed Walleye information
            let walleyeInfo: {String: AnyStruct} = {
                "nftId": fishId,
                "species": metadata.species,
                "scientificName": metadata.scientific,
                "length": metadata.length,
                "location": metadata.location,
                "gear": metadata.gear,
                "latitude": metadata.latitude,
                "longitude": metadata.longitude,
                "timestamp": metadata.timestamp,
                "hasRelease": metadata.hasRelease,
                "bumpShotUrl": metadata.bumpShotUrl,
                "heroShotUrl": metadata.heroShotUrl,
                "mintedBy": nft.mintedBy,
                "mintedAt": nft.mintedAt,
                "speciesCode": metadata.speciesCode,
                "verificationSource": metadata.verificationSource,
                "catchVerified": metadata.catchVerified
            }
            
            walleyeNFTs.append(walleyeInfo)
        }
    }
    
    // Calculate some Walleye statistics
    var totalLength: UFix64 = 0.0
    var maxLength: UFix64 = 0.0
    var minLength: UFix64 = 999.0
    var releasedCount = 0
    var locations: [String] = []
    
    for walleyeInfo in walleyeNFTs {
        let length = walleyeInfo["length"]! as! UFix64
        totalLength = totalLength + length
        
        if length > maxLength {
            maxLength = length
        }
        if length < minLength {
            minLength = length
        }
        
        let hasRelease = walleyeInfo["hasRelease"]! as! Bool
        if hasRelease {
            releasedCount = releasedCount + 1
        }
        
        if let location = walleyeInfo["location"] as! String? {
            if !locations.contains(location) {
                locations.append(location)
            }
        }
    }
    
    let averageLength = walleyeCount > 0 ? totalLength / UFix64(walleyeCount) : 0.0
    
    // Return comprehensive test results
    return {
        "success": true,
        "anglerAddress": anglerAddress.toString(),
        "totalFishCaught": totalFish,
        "walleyeCount": walleyeCount,
        "walleyePercentage": totalFish > 0 ? Float(walleyeCount) / Float(totalFish) * 100.0 : 0.0,
        "walleyeStatistics": {
            "totalLength": totalLength,
            "averageLength": averageLength,
            "maxLength": maxLength,
            "minLength": walleyeCount > 0 ? minLength : 0.0,
            "releasedCount": releasedCount,
            "releasedPercentage": walleyeCount > 0 ? Float(releasedCount) / Float(walleyeCount) * 100.0 : 0.0,
            "uniqueLocations": locations.length,
            "locationsList": locations
        },
        "walleyeNFTs": walleyeNFTs,
        "testingNotes": {
            "message": "This script validates Walleye NFT minting and metadata",
            "recommendations": walleyeCount == 0 ? 
                ["Mint some Walleye NFTs using the mint_fish_nft.cdc transaction"] :
                ["Data looks good! Try minting NFTs from different locations", "Test different Walleye sizes and gear types"]
        }
    }
} 