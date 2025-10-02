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
            let baitVaultCapability = signer.capabilities.storage.issue<&{FungibleToken.Receiver}>(/storage/baitCoinVault)
            signer.capabilities.publish(baitVaultCapability, at: /public/baitCoinReceiver)
            log("BAIT vault created and published")
        } else {
            log("BAIT vault already exists")
        }

    }
}
