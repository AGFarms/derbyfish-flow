import "BaitCoin"
import "FungibleToken"

// Transaction to swap BAIT for USDF tokens
transaction(baitAmount: UFix64) {
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        log("Swapping ".concat(baitAmount.toString()).concat(" BAIT for USDF"))
        
        // Borrow the sender's BAIT vault
        let senderBaitVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &BaitCoin.Vault>(from: /storage/baitCoinVault)
            ?? panic("Could not borrow sender's BAIT vault")
        
        // Withdraw BAIT from sender's vault
        let baitVault <- senderBaitVault.withdraw(amount: baitAmount)
        
        // Use the contract's swap function
        let emptyVault <- BaitCoin.swapBaitToUSDF(baitVault: <-baitVault, userAddress: signer.address)
        destroy emptyVault
        
        log("Successfully swapped ".concat(baitAmount.toString()).concat(" BAIT for USDF"))
    }
}
