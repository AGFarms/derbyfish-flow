import "BaitCoin"
import "FungibleToken"

// Complete reset of all vaults and capabilities
transaction {
    prepare(signer: auth(BorrowValue, Contracts, Storage, Capabilities) &Account) {
        log("Starting complete vault reset for address: ".concat(signer.address.toString()))
        
        // Reset BaitCoin vault
        log("Resetting BaitCoin vault...")
        
        // Unpublish BaitCoin capabilities
        signer.capabilities.unpublish(/public/baitCoinVault)
        signer.capabilities.unpublish(/public/baitCoinReceiver)
        
        // Remove existing BaitCoin vault
        let existingBaitVault <- signer.storage.load<@BaitCoin.Vault>(from: /storage/baitCoinVault)
        destroy existingBaitVault
        log("Removed existing BaitCoin vault (if any)")
        
        // Create fresh BaitCoin vault
        let freshBaitVault <- BaitCoin.createEmptyVault(vaultType: Type<@BaitCoin.Vault>())
        signer.storage.save(<-freshBaitVault, to: /storage/baitCoinVault)
        
        // Publish BaitCoin capabilities
        let baitVaultCapability = signer.capabilities.storage.issue<&{FungibleToken.Receiver}>(/storage/baitCoinVault)
        signer.capabilities.publish(baitVaultCapability, at: /public/baitCoinReceiver)
        log("BaitCoin vault reset complete")
        
        // Test FUSD receiver capability
        log("Testing FUSD receiver capability...")
        let fusdReceiverTest = signer.capabilities.get<&{FungibleToken.Receiver}>(/public/fusdReceiver)
        if fusdReceiverTest != nil {
            let fusdReceiver = fusdReceiverTest.borrow()
            if fusdReceiver != nil {
                log("SUCCESS: FUSD receiver borrowed successfully!")
            } else {
                log("FAILED: Cannot borrow FUSD receiver")
            }
        } else {
            log("ERROR: No FUSD receiver capability found")
        }
        
        // Test BaitCoin receiver capability
        log("Testing BaitCoin receiver capability...")
        let baitReceiverTest = signer.capabilities.get<&{FungibleToken.Receiver}>(/public/baitCoinReceiver)
        if baitReceiverTest != nil {
            let baitReceiver = baitReceiverTest.borrow()
            if baitReceiver != nil {
                log("SUCCESS: BaitCoin receiver borrowed successfully!")
            } else {
                log("FAILED: Cannot borrow BaitCoin receiver")
            }
        } else {
            log("ERROR: No BaitCoin receiver capability found")
        }
        
        log("Complete vault reset finished for ".concat(signer.address.toString()))
    }
}
