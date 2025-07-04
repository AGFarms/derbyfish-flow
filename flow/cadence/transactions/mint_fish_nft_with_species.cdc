import "FishNFT"
import "NonFungibleToken"

transaction(
    // REQUIRED CORE DATA
    recipient: Address,
    species: String,
    scientific: String,
    length: UFix64,
    weight: UFix64?,
    timestamp: UFix64,
    speciesCode: String,
    hasRelease: Bool,
    
    // REQUIRED MEDIA
    bumpShotUrl: String,
    heroShotUrl: String,
    bumpHash: String,
    heroHash: String,
    releaseVideoUrl: String?,
    releaseHash: String?,
    
    // LOCATION DATA
    longitude: Fix64,
    latitude: Fix64,
    waterBody: String?,
    
    // OPTIONAL ENVIRONMENTAL DATA
    waterTemp: UFix64?,
    airTemp: UFix64?,
    weather: String?,
    moonPhase: String?,
    tide: String?,
    barometricPressure: UFix64?,
    windSpeed: UFix64?,
    windDirection: String?,
    skyConditions: String?,
    waterDepth: UFix64?,
    structureType: String?,
    bottomType: String?,
    
    // OPTIONAL ANGLER DATA
    location: String?,
    waterClarity: String?,
    currentStrength: String?,
    gear: String?,
    baitLure: String?,
    fightDuration: UFix64?,
    technique: String?,
    girth: UFix64?,
    rodType: String?,
    reelType: String?,
    lineType: String?,
    leaderType: String?,
    hookType: String?,
    presentation: String?,
    retrieveSpeed: String?,
    catchDepth: UFix64?
) {
    let minter: &FishNFT.NFTMinter
    
    prepare(acct: auth(Storage) &Account) {
        // Borrow minter reference
        self.minter = acct.storage.borrow<&FishNFT.NFTMinter>(from: FishNFT.MinterStoragePath)
            ?? panic("Could not borrow minter")
    }
    
    execute {
        // Step 1: Register species if not already registered (optional - species coins handle their own lists)
        if FishNFT.getSpeciesAddress(speciesCode: speciesCode) == nil {
            // For now, register with a placeholder address - species coins will track their own NFT lists
            FishNFT.registerSpecies(speciesCode: speciesCode, contractAddress: 0xf8d6e0586b0a20c7)
            log("Registered species: ".concat(speciesCode))
        } else {
            log("Species already registered: ".concat(speciesCode))
        }
        
        // Step 2: Mint NFT with all metadata
        let nft <- self.minter.mintNFTWithSpeciesValidation(
            recipient: recipient,
            species: species,
            scientific: scientific,
            length: length,
            weight: weight,
            timestamp: timestamp,
            speciesCode: speciesCode,
            hasRelease: hasRelease,
            bumpShotUrl: bumpShotUrl,
            heroShotUrl: heroShotUrl,
            bumpHash: bumpHash,
            heroHash: heroHash,
            releaseVideoUrl: releaseVideoUrl,
            releaseHash: releaseHash,
            longitude: longitude,
            latitude: latitude,
            waterBody: waterBody,
            waterTemp: waterTemp,
            airTemp: airTemp,
            weather: weather,
            moonPhase: moonPhase,
            tide: tide,
            barometricPressure: barometricPressure,
            windSpeed: windSpeed,
            windDirection: windDirection,
            skyConditions: skyConditions,
            waterDepth: waterDepth,
            structureType: structureType,
            bottomType: bottomType,
            location: location,
            waterClarity: waterClarity,
            currentStrength: currentStrength,
            gear: gear,
            baitLure: baitLure,
            fightDuration: fightDuration,
            technique: technique,
            girth: girth,
            rodType: rodType,
            reelType: reelType,
            lineType: lineType,
            leaderType: leaderType,
            hookType: hookType,
            presentation: presentation,
            retrieveSpeed: retrieveSpeed,
            catchDepth: catchDepth
        )
        
        let nftId = nft.id
        
        // Get recipient's NFT collection reference
        let recipientCollection = getAccount(recipient)
            .capabilities
            .borrow<&{NonFungibleToken.CollectionPublic}>(FishNFT.CollectionPublicPath)
            ?? panic("Could not borrow recipient NFT collection")
        
        // Step 3: Deposit NFT to recipient's collection
        recipientCollection.deposit(token: <-nft)
        log("Fish NFT #".concat(nftId.toString()).concat(" minted and deposited"))
        
        log("NFT MINTING COMPLETE:")
        log("✅ Species registered: ".concat(speciesCode))
        log("✅ Fish NFT minted: #".concat(nftId.toString()))
        log("ℹ️  To mint species coins, use the separate mint-species-coin.cdc transaction")
    }
} 