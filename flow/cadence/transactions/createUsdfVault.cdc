import EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabed from 0x1e4aa0b87d10b141
import "FungibleToken"

// Transaction to create USDF vault for an address
transaction(address: Address) {
    
    prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {
        log("Creating USDF vault for address: ".concat(address.toString()))
        
        // Verify the signer is the target address
        assert(signer.address == address, message: "Signer must be the target address")
        
        // Create USDF vault if it doesn't exist
        let existingUsdfVault = signer.storage.borrow<&EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabed.Vault>(from: /storage/usdfVault)
        if existingUsdfVault == nil {
            log("Creating USDF vault...")
            let emptyUsdfVault <- EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabed.createEmptyVault(vaultType: Type<@EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabed.Vault>())
            signer.storage.save(<-emptyUsdfVault, to: /storage/usdfVault)
            
            // Publish USDF vault capability as Receiver
            let usdfVaultCapability = signer.capabilities.storage.issue<&{FungibleToken.Receiver}>(/storage/usdfVault)
            signer.capabilities.publish(usdfVaultCapability, at: /public/usdfReceiver)
            log("USDF vault created and published")
        } else {
            log("USDF vault already exists")
        }
    }
}
