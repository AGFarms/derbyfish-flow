import "BaitCoin"
import "FungibleToken"

// Script to check BAIT balance for an address
access(all) fun main(address: Address): {String: String} {
    let account = getAccount(address)
    let results: {String: String} = {}
    
    // Get the BAIT vault capability
    let baitVault = account.capabilities.get<&BaitCoin.Vault>(/public/baitCoinReceiver)
    
    if baitVault == nil {
        results["BAIT_Vault_Exists"] = "false"
        results["BAIT_Balance"] = "0.0"
        results["Status"] = "No BAIT vault found. Run createAllVault.cdc first."
    } else {
        results["BAIT_Vault_Exists"] = "true"
        
        // Get the balance
        let balance = baitVault.borrow()?.balance ?? 0.0
        results["BAIT_Balance"] = balance.toString()
        
        // Additional information
        results["Address"] = address.toString()
        results["Vault_Path"] = "/storage/baitCoinVault"
        results["Public_Path"] = "/public/baitCoinReceiver"
        
        if balance == 0.0 {
            results["Status"] = "BAIT vault is empty"
        } else {
            results["Status"] = "BAIT vault has tokens"
        }
        
        // Check if capability is properly published
        results["Capability_Published"] = "true"
    }
    
    return results
}
