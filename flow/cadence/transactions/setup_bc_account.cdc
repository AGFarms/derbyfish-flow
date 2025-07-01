import "FungibleToken"
import "BaitCoin"

transaction () {

    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {

        // Return early if the account already stores a FooToken Vault
        if signer.storage.borrow<&BaitCoin.Vault>(from: BaitCoin.VaultStoragePath) != nil {
            return
        }

        let vault <- BaitCoin.createEmptyVault(vaultType: Type<@BaitCoin.Vault>())

        // Create a new FooToken Vault and put it in storage
        signer.storage.save(<-vault, to: BaitCoin.VaultStoragePath)

        // Create a public capability to the Vault that exposes the Vault interfaces
        let vaultCap = signer.capabilities.storage.issue<&BaitCoin.Vault>(
            BaitCoin.VaultStoragePath
        )
        signer.capabilities.publish(vaultCap, at: BaitCoin.VaultPublicPath)
    }
}
