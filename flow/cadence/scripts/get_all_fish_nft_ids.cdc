import "FishNFT"

access(all) fun main(): [UInt64] {
    // Get the total number of fish NFTs that have been minted
    let totalFish = FishNFT.getTotalFishCaught()
    
    // Create array of all NFT IDs (sequential from 1 to totalFish)
    let allIDs: [UInt64] = []
    var id: UInt64 = 1
    
    while id <= totalFish {
        allIDs.append(id)
        id = id + 1
    }
    
    return allIDs
}