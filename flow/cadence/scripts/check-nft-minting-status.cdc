import "FishNFT"

access(all) fun main(fishNFTIds: [UInt64]): {String: AnyStruct} {
    let result: {String: AnyStruct} = {}
    
    // Get minting status for all requested NFTs
    let mintingStatus = FishNFT.getMintingStatus(nftIds: fishNFTIds)
    
    // Get list of unminted NFTs
    let unmintedNFTs = FishNFT.getUnmintedNFTs(nftIds: fishNFTIds)
    
    // Calculate summary stats
    var mintedCount = 0
    var unmintedCount = 0
    
    for nftId in fishNFTIds {
        if FishNFT.hasSpeciesCoinsBeenMinted(fishNFTId: nftId) {
            mintedCount = mintedCount + 1
        } else {
            unmintedCount = unmintedCount + 1
        }
    }
    
    // Build result
    result["totalRequested"] = fishNFTIds.length
    result["mintedCount"] = mintedCount
    result["unmintedCount"] = unmintedCount
    result["mintingStatus"] = mintingStatus
    result["unmintedNFTs"] = unmintedNFTs
    result["totalMintedInContract"] = FishNFT.getMintedNFTCount()
    result["allMintedNFTIds"] = FishNFT.getAllMintedNFTIds()
    
    return result
} 