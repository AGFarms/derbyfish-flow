import "FishNFT"

access(all) fun main(): {String: Address} {
    return FishNFT.getAllRegisteredSpecies()
}