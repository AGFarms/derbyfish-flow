import "BaitCoin"
import "FungibleToken"

// Transaction to check what vaults are stored in the BaitCoin contract
transaction() {
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        log("Checking contract vaults...")
        
        let contractAccount = getAccount(0xed2202de80195438)
        
        // Check the main USDF vault path
        let usdfVault = contractAccount.storage.borrow<&{FungibleToken.Vault}>(from: /storage/baitCoinUSDCVault)
        if usdfVault != nil {
            log("USDF Vault Balance: ".concat(usdfVault!.balance.toString()))
        } else {
            log("No vault found at /storage/baitCoinUSDCVault")
        }
        
        // Check the secondary USDF vault path
        let usdfVault2 = contractAccount.storage.borrow<&{FungibleToken.Vault}>(from: /storage/baitCoinUSDFVault2)
        if usdfVault2 != nil {
            log("USDF Vault2 Balance: ".concat(usdfVault2!.balance.toString()))
        } else {
            log("No vault found at /storage/baitCoinUSDFVault2")
        }
        
        // Check BAIT total supply
        log("BAIT Total Supply: ".concat(BaitCoin.totalSupply.toString()))
        
        log("Contract vault check complete")
    }
}
