import "BaitCoin"
import "FungibleToken"

// Script to check what vaults are stored in the BaitCoin contract
access(all) fun main(): {String: String} {
    let contractAccount = getAccount(0xed2202de80195438)
    
    let result: {String: String} = {}
    
    // Check the main USDF vault path
    let usdfVault = contractAccount.storage.borrow<&{FungibleToken.Vault}>(from: /storage/baitCoinUSDCVault)
    if usdfVault != nil {
        result["USDF_Vault_Balance"] = usdfVault!.balance.toString()
    } else {
        result["USDF_Vault_Balance"] = "No vault found at /storage/baitCoinUSDCVault"
    }
    
    // Check the secondary USDF vault path
    let usdfVault2 = contractAccount.storage.borrow<&{FungibleToken.Vault}>(from: /storage/baitCoinUSDFVault2)
    if usdfVault2 != nil {
        result["USDF_Vault2_Balance"] = usdfVault2!.balance.toString()
    } else {
        result["USDF_Vault2_Balance"] = "No vault found at /storage/baitCoinUSDFVault2"
    }
    
    // Check BAIT total supply
    result["BAIT_Total_Supply"] = BaitCoin.totalSupply.toString()
    
    return result
}
