import "BaitCoin"
import "FungibleToken"

// Transaction to send BAIT from sender to recipient
transaction(to: Address, amount: UFix64) {
        
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        log("Sending ".concat(amount.toString()).concat(" BAIT to ").concat(to.toString()))
        
        // Borrow the sender's BAIT vault
        let senderVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &BaitCoin.Vault>(from: /storage/baitCoinVault)
            ?? panic("Could not borrow sender's BAIT vault. Did they run createAllVault.cdc?")
        
        // Get the recipient's BAIT receiver capability
        let recipientAccount = getAccount(to)
        let recipientReceiver = recipientAccount.capabilities.get<&{FungibleToken.Receiver}>(/public/baitCoinReceiver)
            .borrow() ?? panic("Could not borrow recipient's BAIT receiver reference. Did they run createAllVault.cdc?")
        
        // Withdraw BAIT from sender's vault
        let baitVault <- senderVault.withdraw(amount: amount)
        
        // Deposit BAIT into recipient's vault
        recipientReceiver.deposit(from: <-baitVault)
        
        }
    
}
