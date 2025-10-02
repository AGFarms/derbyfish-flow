import "FUSD"
import "FungibleToken"

// Transaction to send FUSD from sender to recipient
transaction(to: Address, amount: UFix64) {
        
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        log("Sending ".concat(amount.toString()).concat(" FUSD to ").concat(to.toString()))
        
        // Borrow the sender's FUSD vault
        let senderVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FUSD.Vault>(from: /storage/fusdVault)
            ?? panic("Could not borrow sender's FUSD vault. Did they run createAllVault.cdc?")
        
        // Get the recipient's FUSD receiver capability
        let recipientAccount = getAccount(to)
        let recipientReceiver = recipientAccount.capabilities.get<&{FungibleToken.Receiver}>(/public/fusdReceiver)
            .borrow() ?? panic("Could not borrow recipient's FUSD receiver reference. Did they run createAllVault.cdc?")
        
        // Withdraw FUSD from sender's vault
        let fusdVault <- senderVault.withdraw(amount: amount)
        
        // Deposit FUSD into recipient's vault
        recipientReceiver.deposit(from: <-fusdVault)
    }

}
