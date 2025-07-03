import "FishNFT"
import "WalleyeCoin"
import "NonFungibleToken"
import "FungibleToken"

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
    let fishMinter: &FishNFT.NFTMinter
    let recipientAccount: &Account

    prepare(acct: auth(Storage) &Account) {
        self.fishMinter = acct.storage.borrow<&FishNFT.NFTMinter>(from: FishNFT.MinterStoragePath)
            ?? panic("Could not borrow Fish NFT minter")
        self.recipientAccount = getAccount(recipient)
    }

    execute {
        // Step 1: Register species if not already registered (using WalleyeCoin as example)
        let walleyeCoinAddress: Address = 0xfdd7b15179ce5eb8 // Replace with actual address
        
        if FishNFT.getSpeciesAddress(speciesCode: speciesCode) == nil {
            FishNFT.registerSpecies(speciesCode: speciesCode, contractAddress: walleyeCoinAddress)
            log("Registered species: ".concat(speciesCode))
        }

        // Step 2: Mint Fish NFT with species validation
        let nft <- self.fishMinter.mintNFTWithSpeciesValidation(
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

        let fishNFTId = nft.id

        // Step 3: Deposit Fish NFT to recipient
        let recipientCollection = self.recipientAccount
            .capabilities.borrow<&{NonFungibleToken.Collection}>(/public/FishNFTCollection)
            ?? panic("Could not borrow recipient collection")

        recipientCollection.deposit(token: <-nft)

        // Step 4: Mint species coins
        let walleyeCoinAccount = getAccount(walleyeCoinAddress)
        
        if let coordinatorRef = walleyeCoinAccount.capabilities.borrow<&WalleyeCoin.FishDEXCoordinator>(
            /public/WalleyeCoinFishDEXCoordinator
        ) {
            // Prepare fish data for the species coin
            let fishData: {String: AnyStruct} = {
                "nftId": fishNFTId,
                "speciesCode": speciesCode,
                "angler": recipient
            }
            
            // Call processCatchFromNFT to mint 1.0 species coins
            let speciesVault <- coordinatorRef.processCatchFromNFT(
                fishData: fishData,
                angler: recipient
            )
            
            // Deposit species coins to recipient
            if let anglerVaultRef = self.recipientAccount.capabilities.borrow<&{FungibleToken.Receiver}>(
                /public/WalleyeCoinReceiver
            ) {
                anglerVaultRef.deposit(from: <- speciesVault)
                log("SUCCESS: Minted Fish NFT #".concat(fishNFTId.toString()).concat(" and 1.0 ").concat(speciesCode).concat(" coins!"))
            } else {
                // If angler doesn't have a vault, destroy the tokens
                destroy speciesVault
                log("WARNING: Fish NFT minted but angler doesn't have species coin vault - coins destroyed")
            }
        } else {
            log("WARNING: Fish NFT minted but could not mint species coins - coordinator not found")
        }
    }
} 