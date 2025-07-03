import "FungibleToken"
import "WalleyeCoin"

transaction () {

    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {

        // Return early if the account already stores a FooToken Vault
        if signer.storage.borrow<&WalleyeCoin.Vault>(from: /storage/WalleyeCoinVault) != nil {
            return
        }

        let vault <- WalleyeCoin.createEmptyVault(vaultType: Type<@WalleyeCoin.Vault>())

        // Create a new FooToken Vault and put it in storage
        signer.storage.save(<-vault, to: /storage/WalleyeCoinVault)

        // Create a public capability to the Vault that exposes the Vault interfaces
        let vaultCap = signer.capabilities.storage.issue<&WalleyeCoin.Vault>(
            /storage/WalleyeCoinVault
        )
        signer.capabilities.publish(vaultCap, at: /public/WalleyeCoinReceiver)
    }
}

