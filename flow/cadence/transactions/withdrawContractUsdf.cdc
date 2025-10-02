import "BaitCoin"

// Transaction to withdraw USDF from contract back to user account
transaction(amount: UFix64) {
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        log("Withdrawing ".concat(amount.toString()).concat(" USDF from contract to user account"))
        
        // Use the contract's withdrawUSDF function
        BaitCoin.withdrawUSDF(amount: amount, recipient: signer.address)
        
        log("Successfully withdrew ".concat(amount.toString()).concat(" USDF from contract"))
    }
}
