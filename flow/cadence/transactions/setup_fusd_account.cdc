import "FungibleToken"
import "FUSD"

transaction () {

    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {

        // Return early if the account already stores a FUSD Vault
        if signer.storage.borrow<&FUSD.Vault>(from: /storage/fusdVault) != nil {
            return
        }

        let vault <- FUSD.createEmptyVault(vaultType: Type<@FUSD.Vault>())

        // Create a new FUSD Vault and put it in storage
        signer.storage.save(<-vault, to: /storage/fusdVault)

        // Create a public capability to the Vault that exposes the balance
        let vaultCap = signer.capabilities.storage.issue<&FUSD.Vault>(
            /storage/fusdVault
        )
        signer.capabilities.publish(vaultCap, at: /public/fusdBalance)

        // Create a public Capability to the Vault's Receiver functionality
        let receiverCap = signer.capabilities.storage.issue<&FUSD.Vault>(
            /storage/fusdVault
        )
        signer.capabilities.publish(receiverCap, at: /public/fusdReceiver)
    }
}