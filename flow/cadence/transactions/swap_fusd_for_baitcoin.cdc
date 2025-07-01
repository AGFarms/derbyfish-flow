import "FungibleToken"
import "FUSD"
import "BaitCoin"

transaction(amount: UFix64, recipient: Address) {
    
    let fusdVault: @FUSD.Vault

    prepare(signer: auth(BorrowValue) &Account) {
        // Withdraw FUSD from signer's vault
        let userFUSDVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FUSD.Vault>(from: /storage/fusdVault)
            ?? panic("Could not borrow FUSD vault from signer")
        
        self.fusdVault <- userFUSDVault.withdraw(amount: amount) as! @FUSD.Vault
    }

    execute {
        // Call the public swap function - no admin access needed!
        BaitCoin.swapFUSDForBaitCoin(from: <-self.fusdVault, recipient: recipient)
    }
}