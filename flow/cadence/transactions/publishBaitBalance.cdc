import BaitCoin from 0xed2202de80195438
import FungibleToken from 0xf233dcee88fe0abe

// Transaction to publish BAIT balance capability for public viewing
transaction {
    
    prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {
        log("Publishing BAIT balance capability for address: ".concat(signer.address.toString()))
        
        // Check if BAIT vault exists
        let existingBaitVault = signer.storage.borrow<&BaitCoin.Vault>(from: /storage/baitCoinVault)
        if existingBaitVault == nil {
            panic("BAIT vault does not exist. Please create it first using createAllVault.cdc")
        }
        
        // Publish BAIT vault balance capability
        let baitBalanceCapability = signer.capabilities.storage.issue<&{FungibleToken.Balance}>(/storage/baitCoinVault)
        signer.capabilities.publish(baitBalanceCapability, at: /public/baitCoinVault)
        
        log("BAIT balance capability published at /public/baitCoinVault")
        
        // Also publish the full vault capability for compatibility
        let baitVaultCapability = signer.capabilities.storage.issue<&BaitCoin.Vault>(/storage/baitCoinVault)
        signer.capabilities.publish(baitVaultCapability, at: /public/baitCoinVaultFull)
        
        log("BAIT full vault capability published at /public/baitCoinVaultFull")
    }
}
