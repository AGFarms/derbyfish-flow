import "FishNFT"

transaction(speciesCode: String, contractAddress: Address) {
    prepare(acct: auth(Storage) &Account) {
        // Only the FishNFT account can register species (for now)
        assert(acct.address == 0xf8d6e0586b0a20c7, message: "Only FishNFT admin can register species")
    }

    execute {
        FishNFT.registerSpecies(speciesCode: speciesCode, contractAddress: contractAddress)
        log("Registered species: ".concat(speciesCode).concat(" -> ").concat(contractAddress.toString()))
    }
} 