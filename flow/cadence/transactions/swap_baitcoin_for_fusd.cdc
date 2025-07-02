import "FungibleToken"
import "FUSD"
import "BaitCoin"

transaction(amount: UFix64, recipient: Address) {
    
    let baitCoinVault: @BaitCoin.Vault

    prepare(signer: auth(BorrowValue) &Account) {
        // Withdraw BaitCoin from signer's vault
        let userBaitCoinVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &BaitCoin.Vault>(from: BaitCoin.VaultStoragePath)
            ?? panic("Could not borrow BaitCoin vault from signer")
        
        self.baitCoinVault <- userBaitCoinVault.withdraw(amount: amount) as! @BaitCoin.Vault
    }

    execute {
        // Call the public swap function - no admin access needed!
        BaitCoin.swapBaitCoinForFUSD(from: <-self.baitCoinVault, recipient: recipient)
    }
}