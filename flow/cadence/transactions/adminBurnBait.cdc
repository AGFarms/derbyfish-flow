import "BaitCoin"
import "FungibleToken"

// Admin transaction to burn BAIT tokens from admin's own vault
transaction(amount: UFix64) {
        
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        log("Admin burning ".concat(amount.toString()).concat(" BAIT from own vault"))
        
        // Verify the signer is the admin
        assert(signer.address == 0xed2202de80195438, message: "Signer must be the admin")
        
        // Borrow the admin resource from the signer's storage
        let adminResource = signer.storage.borrow<&BaitCoin.Admin>(from: /storage/baitCoinAdmin)
            ?? panic("Could not borrow admin resource. Admin must have the admin resource.")
        
        // Get the admin's own BAIT vault to burn from
        let adminVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &BaitCoin.Vault>(from: /storage/baitCoinVault)
            ?? panic("Could not borrow admin's BAIT vault. Admin must have a BAIT vault.")
        
        // Withdraw tokens from admin's vault
        let tokensToBurn <- adminVault.withdraw(amount: amount)
        
        // Burn the tokens (destroy them and reduce total supply)
        BaitCoin.burnTokens(amount: amount)
        destroy tokensToBurn
        
        log("Successfully burned ".concat(amount.toString()).concat(" BAIT from admin vault"))
    }
    
}
