import "BaitCoin"
import "FungibleToken"

// Transaction to create all necessary vaults for an address
transaction(address: Address) {
    
    prepare(signer: auth(BorrowValue, Contracts, Storage, Capabilities) &Account) {
        log("Creating all vaults for address: ".concat(address.toString()))
        
        // Verify the signer is the target address
        assert(signer.address == address, message: "Signer must be the target address")
        
        // Create BAIT vault if it doesn't exist
        let existingBaitVault = signer.storage.borrow<&BaitCoin.Vault>(from: /storage/baitCoinVault)
        if existingBaitVault == nil {
            log("Creating BAIT vault...")
            let emptyBaitVault <- BaitCoin.createEmptyVault(vaultType: Type<@BaitCoin.Vault>())
            signer.storage.save(<-emptyBaitVault, to: /storage/baitCoinVault)
            
            // Publish BAIT vault capability as Receiver
            let baitReceiverCapability = signer.capabilities.storage.issue<&{FungibleToken.Receiver}>(/storage/baitCoinVault)
            signer.capabilities.publish(baitReceiverCapability, at: /public/baitCoinReceiver)
            
            // Publish BAIT vault balance capability for public viewing
            let baitBalanceCapability = signer.capabilities.storage.issue<&{FungibleToken.Balance}>(/storage/baitCoinVault)
            signer.capabilities.publish(baitBalanceCapability, at: /public/baitCoinVault)
            
            log("BAIT vault created and published with receiver and balance capabilities")
        } else {
            log("BAIT vault already exists")
            
            // Check if balance capability is published, if not, publish it
            let existingBalanceCapability = signer.capabilities.get<&{FungibleToken.Balance}>(/public/baitCoinVault)
            if existingBalanceCapability == nil {
                log("Publishing missing BAIT balance capability...")
                let baitBalanceCapability = signer.capabilities.storage.issue<&{FungibleToken.Balance}>(/storage/baitCoinVault)
                signer.capabilities.publish(baitBalanceCapability, at: /public/baitCoinVault)
                log("BAIT balance capability published")
            } else {
                log("BAIT balance capability already published")
            }
        }

    }
}
