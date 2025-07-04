import "FishNFT"
import "WalleyeCoin"
import "NonFungibleToken"
import "FungibleToken"

transaction(
    recipient: Address,
    fishNFTIds: [UInt64]
) {
    let recipientAccount: &Account

    prepare(acct: auth(Storage) &Account) {
        self.recipientAccount = getAccount(recipient)
    }

    execute {
        let walleyeCoinAddress: Address = 0xfdd7b15179ce5eb8
        
        // First, check which NFTs haven't been minted yet (batch check)
        let unmintedNFTs = FishNFT.getUnmintedNFTs(nftIds: fishNFTIds)
        
        if unmintedNFTs.length == 0 {
            log("All specified Fish NFTs have already had species coins minted - nothing to do")
            return
        }
        
        log("Processing ".concat(unmintedNFTs.length.toString()).concat(" unminted NFTs out of ").concat(fishNFTIds.length.toString()).concat(" total"))
        
        // Get recipient's Fish NFT collection
        let recipientCollection = self.recipientAccount
            .capabilities.borrow<&{NonFungibleToken.Collection}>(/public/FishNFTCollection)
            ?? panic("Could not borrow recipient collection")
        
        // Get WalleyeCoin coordinator
        let walleyeCoinAccount = getAccount(walleyeCoinAddress)
        let coordinatorRef = walleyeCoinAccount.capabilities.borrow<&WalleyeCoin.FishDEXCoordinator>(
            /public/WalleyeCoinFishDEXCoordinator
        ) ?? panic("Could not borrow WalleyeCoin coordinator")
        
        // Get recipient's species coin vault
        let anglerVaultRef = self.recipientAccount.capabilities.borrow<&{FungibleToken.Receiver}>(
            /public/WalleyeCoinReceiver
        ) ?? panic("Could not borrow recipient species coin vault")
        
        var totalMinted: UInt64 = 0
        var skippedCount: UInt64 = 0
        
        // Process each unminted Fish NFT ID
        for fishNFTId in unmintedNFTs {
            // Double-check in case of concurrent minting (race condition protection)
            if FishNFT.hasSpeciesCoinsBeenMinted(fishNFTId: fishNFTId) {
                log("Fish NFT #".concat(fishNFTId.toString()).concat(" was minted by another transaction - skipping"))
                skippedCount = skippedCount + 1
                continue
            }
            
            // Get the Fish NFT to extract species data
            let fishNFT = recipientCollection.borrowEntireNFT(id: fishNFTId)
                ?? panic("Could not borrow Fish NFT with ID ".concat(fishNFTId.toString()))
            
            let speciesCode = fishNFT.speciesCode
            
            // Only process Walleye fish for this coin type
            if speciesCode != "SANDER_VITREUS" {
                log("Fish NFT #".concat(fishNFTId.toString()).concat(" is not a Walleye (").concat(speciesCode).concat(") - skipping"))
                skippedCount = skippedCount + 1
                continue
            }
            
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
            anglerVaultRef.deposit(from: <- speciesVault)
            
            // Mark that species coins have been minted for this NFT
            FishNFT.markSpeciesCoinsAsMinted(fishNFTId: fishNFTId)
            
            totalMinted = totalMinted + 1
            log("Minted 1.0 ".concat(speciesCode).concat(" coins for Fish NFT #").concat(fishNFTId.toString()))
        }
        
        // Final summary
        log("COMPLETED: Minted species coins for ".concat(totalMinted.toString()).concat(" Fish NFTs"))
        if skippedCount > 0 {
            log("SKIPPED: ".concat(skippedCount.toString()).concat(" Fish NFTs (already minted or wrong species)"))
        }
        
        // Show final status
        let finalStatus = FishNFT.getMintingStatus(nftIds: fishNFTIds)
        log("Final minting status for all requested NFTs:")
        for nftId in fishNFTIds {
            let status = finalStatus[nftId] ?? false
            log("NFT #".concat(nftId.toString()).concat(": ").concat(status ? "MINTED" : "NOT MINTED"))
        }
    }
}