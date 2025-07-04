import "FishNFT"

transaction(speciesCode: String, contractAddress: Address) {
    prepare(acct: auth(Storage) &Account) {
        // No admin check needed for emulator testing
        // In production, you would add proper access control
    }

    execute {
        // Register the species code with its contract address
        FishNFT.registerSpecies(speciesCode: speciesCode, contractAddress: contractAddress)
        
        log("✅ Species registered successfully!")
        log("Species code: ".concat(speciesCode))
        log("Contract address: ".concat(contractAddress.toString()))
    }
} 