import "FungibleToken"
import "WalleyeCoin"

transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Check if vault already exists
        if signer.storage.borrow<&WalleyeCoin.Vault>(from: WalleyeCoin.VaultStoragePath) != nil {
            return
        }

        // Create empty vault
        let vault <- WalleyeCoin.createEmptyVault(vaultType: Type<@WalleyeCoin.Vault>())
        
        // Save vault to storage
        signer.storage.save(<-vault, to: WalleyeCoin.VaultStoragePath)

        // Create public capabilities
        let vaultCap = signer.capabilities.storage.issue<&{FungibleToken.Receiver, FungibleToken.Balance}>(
            WalleyeCoin.VaultStoragePath
        )
        signer.capabilities.publish(vaultCap, at: WalleyeCoin.VaultPublicPath)
    }
}

