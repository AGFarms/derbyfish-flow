import "FishNFT"
import "NonFungibleToken"

transaction(
    recipient: Address,
    species: String,
    scientific: String,
    length: UFix64,
    weight: UFix64?,
    timestamp: UFix64,
    speciesCode: String,
    hasRelease: Bool,
    bumpShotUrl: String,
    heroShotUrl: String,
    bumpHash: String,
    heroHash: String,
    releaseVideoUrl: String?,
    releaseHash: String?,
    longitude: Fix64,
    latitude: Fix64,
    waterBody: String?,
    gear: String?,
    location: String?
) {
    let minter: &FishNFT.NFTMinter

    prepare(acct: auth(Storage) &Account) {
        self.minter = acct.storage.borrow<&FishNFT.NFTMinter>(from: FishNFT.MinterStoragePath)
            ?? panic("Could not borrow minter")
    }

    execute {
        // Check if species is registered first
        if FishNFT.getSpeciesAddress(speciesCode: speciesCode) == nil {
            panic("Species code ".concat(speciesCode).concat(" not registered. Run register_species.cdc first."))
        }

        // Mint NFT with basic metadata (no species coins)
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
            waterTemp: nil,
            airTemp: nil,
            weather: nil,
            moonPhase: nil,
            tide: nil,
            barometricPressure: nil,
            windSpeed: nil,
            windDirection: nil,
            skyConditions: nil,
            waterDepth: nil,
            structureType: nil,
            bottomType: nil,
            location: location,
            waterClarity: nil,
            currentStrength: nil,
            gear: gear,
            baitLure: nil,
            fightDuration: nil,
            technique: nil,
            girth: nil,
            rodType: nil,
            reelType: nil,
            lineType: nil,
            leaderType: nil,
            hookType: nil,
            presentation: nil,
            retrieveSpeed: nil,
            catchDepth: nil
        )

        let nftId = nft.id

        // Get recipient's collection reference
        let recipientCollection = getAccount(recipient)
            .capabilities
            .borrow<&{NonFungibleToken.CollectionPublic}>(FishNFT.CollectionPublicPath)
            ?? panic("Could not borrow recipient collection")

        // Deposit NFT to recipient's collection
        recipientCollection.deposit(token: <-nft)

        log("✅ Fish NFT minted successfully!")
        log("NFT ID: ".concat(nftId.toString()))
        log("Species: ".concat(species))
        log("Species Code: ".concat(speciesCode))
        log("Note: Species coins NOT minted - use mint-species-coin.cdc separately")
    }
}