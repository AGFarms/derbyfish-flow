import "FungibleToken"
import "FUSD"

transaction(recipient: Address, amount: UFix64) {

    let fusdVault: @FUSD.Vault

    prepare(signer: auth(BorrowValue) &Account) {
        let userFUSDVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FUSD.Vault>(from: /storage/fusdVault)
            ?? panic("Could not borrow FUSD vault from signer. Make sure you have FUSD set up in your account!")

        self.fusdVault <- userFUSDVault.withdraw(amount: amount) as! @FUSD.Vault
    }

    execute {
        let recipientReceiver = getAccount(recipient).capabilities.borrow<&{FungibleToken.Receiver}>(/public/fusdReceiver)
            ?? panic("Could not borrow a Receiver reference to the FungibleToken Vault in account "
                .concat(recipient.toString()).concat(" at path ").concat("/public/fusdReceiver")
                .concat(". Make sure you are sending to an address that has ")
                .concat("a FungibleToken Vault set up properly at the specified path."))

        recipientReceiver.deposit(from: <-self.fusdVault)
    }
} 