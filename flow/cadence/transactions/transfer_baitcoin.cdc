import "FungibleToken"
import "BaitCoin"

transaction(to: Address, amount: UFix64) {

    // The Vault resource that holds the tokens that are being transferred
    let sentVault: @{FungibleToken.Vault}

    prepare(signer: auth(BorrowValue) &Account) {

        // Get a reference to the signer's stored vault
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &BaitCoin.Vault>(from: BaitCoin.VaultStoragePath)
            ?? panic("The signer does not store an BaitCoin.Vault object at the path "
                    .concat(BaitCoin.VaultStoragePath.toString())
                    .concat(". The signer must initialize their account with this vault first!"))

        // Withdraw tokens from the signer's stored vault
        self.sentVault <- vaultRef.withdraw(amount: amount)
    }

    execute {

        // Get the recipient's public account object
        let recipient = getAccount(to)

        // Get a reference to the recipient's Receiver
        let receiverRef = recipient.capabilities.borrow<&{FungibleToken.Receiver}>(BaitCoin.VaultPublicPath)
            ?? panic("Could not borrow a Receiver reference to the BaitCoin Vault in account "
                .concat(recipient.address.toString()).concat(" at path ").concat(BaitCoin.VaultPublicPath.toString())
                .concat(". Make sure you are sending to an address that has ")
                .concat("a BaitCoin Vault set up properly at the specified path."))

        // Deposit the withdrawn tokens in the recipient's receiver
        receiverRef.deposit(from: <-self.sentVault)
    }
}
