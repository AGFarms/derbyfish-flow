import "FishNFT"
import "NonFungibleToken"

transaction(
    recipient: Address,
    bumpShotUrl: String,
    heroShotUrl: String,
    hasRelease: Bool,
    releaseVideoUrl: String?,
    bumpHash: String,
    heroHash: String,
    releaseHash: String?,
    longitude: Fix64,
    latitude: Fix64,
    length: UFix64,
    species: String,
    scientific: String,
    timestamp: UFix64,
    gear: String?,
    location: String?,
    speciesCode: String
) {
    let minter: &FishNFT.NFTMinter

    prepare(acct: auth(Storage) &Account) {
        self.minter = acct.storage.borrow<&FishNFT.NFTMinter>(from: FishNFT.MinterStoragePath)
            ?? panic("Could not borrow minter")
    }

    execute {
        // Use the enhanced minting function that includes species validation
        let nft <- self.minter.mintNFTWithSpeciesValidation(
            recipient: recipient,
            bumpShotUrl: bumpShotUrl,
            heroShotUrl: heroShotUrl,
            hasRelease: hasRelease,
            releaseVideoUrl: releaseVideoUrl,
            bumpHash: bumpHash,
            heroHash: heroHash,
            releaseHash: releaseHash,
            longitude: longitude,
            latitude: latitude,
            length: length,
            species: species,
            scientific: scientific,
            timestamp: timestamp,
            gear: gear,
            location: location,
            speciesCode: speciesCode
        )

        let recipientCollection = getAccount(recipient)
            .capabilities.borrow<&{NonFungibleToken.Collection}>(/public/FishNFTCollection)
            ?? panic("Could not borrow recipient collection")

        recipientCollection.deposit(token: <-nft)
        
        log("Fish NFT minted with species validation!")
        log("Species: ".concat(species))
        log("Scientific: ".concat(scientific))
        log("Species Code: ".concat(speciesCode))
    }
} 