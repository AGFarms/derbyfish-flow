import "BaitCoin"
import "FungibleToken"

// Admin transaction to mint BAIT tokens directly to a recipient
transaction(to: Address, amount: UFix64) {
        
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        log("Admin minting ".concat(amount.toString()).concat(" BAIT to ").concat(to.toString()))
        
        // Borrow the admin resource from the signer's storage
        let adminResource = signer.storage.borrow<&BaitCoin.Admin>(from: /storage/baitCoinAdmin)
            ?? panic("Could not borrow admin resource. Signer must be the admin.")
        
        // Get the recipient's BAIT receiver capability
        let recipientAccount = getAccount(to)
        let recipientReceiver = recipientAccount.capabilities.get<&{FungibleToken.Receiver}>(/public/baitCoinReceiver)
            .borrow() ?? panic("Could not borrow recipient's BAIT receiver reference. Did they run createAllVault.cdc?")
        
        // Mint BAIT tokens directly to the recipient
        adminResource.mintBait(amount: amount, recipient: to)
        
    }
    
}
