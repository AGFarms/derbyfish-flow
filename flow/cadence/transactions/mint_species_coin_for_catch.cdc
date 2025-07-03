import "WalleyeCoin"
import "FungibleToken"

transaction(
    angler: Address,
    fishNFTId: UInt64,
    speciesCode: String
) {
    let signerAccount: auth(Storage) &Account
    let anglerAccount: &Account

    prepare(acct: auth(Storage) &Account) {
        self.signerAccount = acct
        self.anglerAccount = getAccount(angler)
    }

    execute {
        // Get reference to the WalleyeCoin coordinator
        let walleyeCoinAccount = getAccount(0xf8d6e0586b0a20c7) // Replace with actual contract address
        
        if let coordinatorRef = walleyeCoinAccount.capabilities.borrow<&WalleyeCoin.FishDEXCoordinator>(
            /public/WalleyeCoinFishDEXCoordinator
        ) {
            // Prepare fish data for the species coin
            let fishData: {String: AnyStruct} = {
                "nftId": fishNFTId,
                "speciesCode": speciesCode,
                "angler": angler
            }
            
            // Call processCatchFromNFT to mint 1.0 species coins
            let speciesVault <- coordinatorRef.processCatchFromNFT(
                fishData: fishData,
                angler: angler
            )
            
            // Get the angler's species coin vault and deposit
            if let anglerVaultRef = self.anglerAccount.capabilities.borrow<&{FungibleToken.Receiver}>(
                /public/WalleyeCoinReceiver
            ) {
                anglerVaultRef.deposit(from: <- speciesVault)
                log("Minted 1.0 ".concat(speciesCode).concat(" coins for angler: ").concat(angler.toString()))
            } else {
                // If angler doesn't have a vault, destroy the tokens
                destroy speciesVault
                log("Angler doesn't have a species coin vault - tokens destroyed")
            }
        } else {
            log("Could not borrow WalleyeCoin coordinator")
        }
    }
} 