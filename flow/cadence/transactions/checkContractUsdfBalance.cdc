import "BaitCoin"
import "FungibleToken"

// Transaction to check the contract's USDF vault balance
transaction() {
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        log("Checking contract USDF balance...")
        
        let contractAccount = getAccount(0xed2202de80195438)
        
        // Check the EVM USDF vault path
        let usdfVault = contractAccount.storage.borrow<&{FungibleToken.Vault}>(from: /storage/baitCoinEVMUSDFVault)
        if usdfVault != nil {
            log("Contract USDF Balance: ".concat(usdfVault!.balance.toString()))
        } else {
            log("No USDF vault found at /storage/baitCoinEVMUSDFVault")
        }
        
        // Also check BAIT total supply
        log("BAIT Total Supply: ".concat(BaitCoin.totalSupply.toString()))
        
        log("Check complete")
    }
}
