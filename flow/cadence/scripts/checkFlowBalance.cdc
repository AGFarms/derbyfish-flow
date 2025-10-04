import "FlowToken"
import "FungibleToken"

// Script to check FLOW balance for an address
access(all) fun main(address: Address): {String: String} {
    let account = getAccount(address)
    let results: {String: String} = {}
    
    // Get the FLOW vault capability
    let flowVault = account.capabilities.get<&FlowToken.Vault>(/public/flowTokenReceiver)
    
    if flowVault == nil {
        results["FLOW_Vault_Exists"] = "false"
        results["FLOW_Balance"] = "0.0"
        results["Status"] = "No FLOW vault found. Account may not be initialized."
    } else {
        results["FLOW_Vault_Exists"] = "true"
        
        // Get the balance
        let balance = flowVault.borrow()?.balance ?? 0.0
        results["FLOW_Balance"] = balance.toString()
        
        // Additional information
        results["Address"] = address.toString()
        results["Vault_Path"] = "/storage/flowTokenVault"
        results["Public_Path"] = "/public/flowTokenReceiver"
        
        if balance == 0.0 {
            results["Status"] = "FLOW vault is empty"
        } else {
            results["Status"] = "FLOW vault has tokens"
        }
        
        // Check if capability is properly published
        results["Capability_Published"] = "true"
    }
    
    return results
}
