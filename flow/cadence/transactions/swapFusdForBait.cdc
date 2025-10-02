import EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabed from 0x1e4aa0b87d10b141
import "BaitCoin"
import "FungibleToken"

// Transaction to swap FUSD for BAIT tokens
transaction(fusdAmount: UFix64) {
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        log("Swapping ".concat(fusdAmount.toString()).concat(" FUSD for BAIT"))
        
        // Borrow the sender's FUSD vault
        let senderFusdVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(from: /storage/usdfVault)
            ?? panic("Could not borrow sender's FUSD vault. Did they run createAllVault.cdc?")
        
        // Withdraw FUSD from sender's vault
        let fusdVault <- senderFusdVault.withdraw(amount: fusdAmount)
        
        // Get the BaitCoin contract account
        let contractAccount = getAccount(0xed2202de80195438)
        
        // Use the contract's built-in swap function
        let emptyVault <- BaitCoin.swapUSDFToBait(usdfVault: <-fusdVault, userAddress: signer.address)
        destroy emptyVault
        
        log("Successfully swapped ".concat(fusdAmount.toString()).concat(" FUSD for BAIT"))
    }
    
}
