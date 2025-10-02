import "FUSD"
import "BaitCoin"
import "FungibleToken"

// Script to create vaults and mint initial tokens for an address
access(all) fun main(address: Address, mintAmount: UFix64): {String: String} {
    let account = getAccount(address)
    let results: {String: String} = {}
    
    // Check if FUSD vault exists
    let fusdVault = account.capabilities.get<&FUSD.Vault>(/public/fusdReceiver)
    if fusdVault != nil {
        results["FUSD_Vault_Exists"] = "true"
        let fusdBalance = fusdVault.borrow()?.balance
        results["FUSD_Balance"] = fusdBalance?.toString() ?? "0.0"
    } else {
        results["FUSD_Vault_Exists"] = "false"
        results["FUSD_Balance"] = "0.0"
    }
    
    // Check if BAIT vault exists
    let baitVault = account.capabilities.get<&BaitCoin.Vault>(/public/baitCoinReceiver)
    if baitVault != nil {
        results["BAIT_Vault_Exists"] = "true"
        let baitBalance = baitVault.borrow()?.balance
        results["BAIT_Balance"] = baitBalance?.toString() ?? "0.0"
    } else {
        results["BAIT_Vault_Exists"] = "false"
        results["BAIT_Balance"] = "0.0"
    }
    
    // Check if vaults are ready for minting
    let fusdReady = fusdVault != nil && fusdVault.borrow() != nil
    let baitReady = baitVault != nil && baitVault.borrow() != nil
    
    results["FUSD_Ready_For_Mint"] = fusdReady ? "true" : "false"
    results["BAIT_Ready_For_Mint"] = baitReady ? "true" : "false"
    
    // Check if address has admin capabilities (for testing)
    let adminCapability = account.capabilities.get<&BaitCoin.Admin>(/public/baitCoinAdmin)
    results["Has_BAIT_Admin"] = adminCapability != nil ? "true" : "false"
    
    let fusdAdminCapability = account.capabilities.get<&FUSD.Minter>(/public/fusdAdmin)
    results["Has_FUSD_Admin"] = fusdAdminCapability != nil ? "true" : "false"
    
    // Return vault status and readiness for minting
    results["Vaults_Created"] = (fusdReady && baitReady) ? "true" : "false"
    results["Ready_For_Mint_Amount"] = mintAmount.toString()
    
    return results
}
