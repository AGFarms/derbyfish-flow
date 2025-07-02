import "FungibleToken"
import "FUSD"

transaction(recipient: Address, amount: UFix64) {

    /// Reference to the FUSD Minter Resource object
    let tokenMinter: &FUSD.Minter

    /// Reference to the Fungible Token Receiver of the recipient
    let tokenReceiver: &{FungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {

        // Borrow a reference to the admin/minter object (stored at AdminStoragePath)
        self.tokenMinter = signer.storage.borrow<&FUSD.Minter>(from: /storage/fusdAdmin)
            ?? panic("Cannot mint: Signer does not store the FUSD Minter in their account!")

        self.tokenReceiver = getAccount(recipient).capabilities.borrow<&{FungibleToken.Receiver}>(/public/fusdReceiver)
            ?? panic("Could not borrow a Receiver reference to the FungibleToken Vault in account "
                .concat(recipient.toString()).concat(" at path ").concat("/public/fusdReceiver")
                .concat(". Make sure you are sending to an address that has ")
                .concat("a FungibleToken Vault set up properly at the specified path."))
    }

    execute {

        // Create mint tokens
        let mintedVault <- self.tokenMinter.mintTokens(amount: amount)

        // Deposit them to the receiever
        self.tokenReceiver.deposit(from: <-mintedVault)
    }
}