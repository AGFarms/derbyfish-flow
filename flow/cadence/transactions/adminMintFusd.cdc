import "FUSD"
import "FungibleToken"

// Admin transaction to mint FUSD tokens directly to a recipient
transaction(to: Address, amount: UFix64) {
    
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        log("Admin minting ".concat(amount.toString()).concat(" FUSD to ").concat(to.toString()))
        
        // Borrow the admin resource from the signer's storage
        let adminResource = signer.storage.borrow<&FUSD.Minter>(from: /storage/fusdAdmin)
            ?? panic("Could not borrow admin resource. Signer must be the admin.")
        
        // Get the recipient's FUSD receiver capability
        let recipientAccount = getAccount(to)
        let recipientReceiver = recipientAccount.capabilities.get<&{FungibleToken.Receiver}>(/public/fusdReceiver)
            .borrow() ?? panic("Could not borrow recipient's FUSD receiver reference. Did they run createAllVault.cdc?")
        
        // Mint FUSD tokens and deposit them to the recipient
        let mintedTokens <- adminResource.mintTokens(amount: amount)
        recipientReceiver.deposit(from: <-mintedTokens)
        
    }
    
}
