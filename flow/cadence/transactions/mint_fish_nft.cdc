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
    location: String?
) {
    let minter: &FishNFT.NFTMinter

    prepare(acct: &Account) {
        self.minter = acct.storage.borrow<&FishNFT.NFTMinter>(from: FishNFT.MinterStoragePath)
            ?? panic("Could not borrow minter")
    }

    execute {
        let metadata = FishNFT.FishMetadata(
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
            location: location
        )

        let nft <- self.minter.mintNFT(
            recipient: recipient,
            metadata: metadata
        )

        let recipientCollection = getAccount(recipient)
            .capabilities.borrow<&{NonFungibleToken.Collection}>(/public/FishNFTCollection)
            ?? panic("Could not borrow recipient collection")

        recipientCollection.deposit(token: <-nft)
    }
}
