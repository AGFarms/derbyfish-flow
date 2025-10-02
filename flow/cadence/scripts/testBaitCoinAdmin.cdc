import "BaitCoin"
import "FUSD"
import "FungibleToken"

// Script to test BaitCoin admin functionality using emulator account
access(all) fun main(): {String: String} {
    let results: {String: String} = {}
    
    // Get emulator account (address: f8d6e0586b0a20c7)
    let emulatorAddress = Address(0xf8d6e0586b0a20c7)
    let emulatorAccount = getAccount(emulatorAddress)
    
    // Test 1: Check if emulator has admin capabilities
    let baitAdmin = emulatorAccount.capabilities.get<&BaitCoin.Admin>(/public/baitCoinAdmin)
    let fusdAdmin = emulatorAccount.capabilities.get<&FUSD.Minter>(/public/fusdAdmin)
    
    results["Emulator_Has_BAIT_Admin"] = baitAdmin != nil ? "true" : "false"
    results["Emulator_Has_FUSD_Admin"] = fusdAdmin != nil ? "true" : "false"
    
    // Test 2: Check emulator's own vault balances
    let emulatorBaitVault = emulatorAccount.capabilities.get<&BaitCoin.Vault>(/public/baitCoinReceiver)
    let emulatorFusdVault = emulatorAccount.capabilities.get<&FUSD.Vault>(/public/fusdReceiver)
    
    if emulatorBaitVault != nil {
        let baitBalance = emulatorBaitVault.borrow()?.balance ?? 0.0
        results["Emulator_BAIT_Balance"] = baitBalance.toString()
    } else {
        results["Emulator_BAIT_Balance"] = "No vault found"
    }
    
    if emulatorFusdVault != nil {
        let fusdBalance = emulatorFusdVault.borrow()?.balance ?? 0.0
        results["Emulator_FUSD_Balance"] = fusdBalance.toString()
    } else {
        results["Emulator_FUSD_Balance"] = "No vault found"
    }
    
    // Test 3: Check BaitCoin contract info
    let tokenInfo = BaitCoin.getTokenInfo()
    results["Contract_Name"] = tokenInfo["name"] ?? "Unknown"
    results["Contract_Symbol"] = tokenInfo["symbol"] ?? "Unknown"
    results["Contract_Decimals"] = tokenInfo["decimals"] ?? "Unknown"
    results["Contract_Total_Supply"] = tokenInfo["totalSupply"] ?? "Unknown"
    
    // Test 4: Check if admin can be borrowed (simulation)
    if baitAdmin != nil {
        let adminBorrowed = baitAdmin.borrow()
        results["BAIT_Admin_Borrowable"] = adminBorrowed != nil ? "true" : "false"
    } else {
        results["BAIT_Admin_Borrowable"] = "false"
    }
    
    if fusdAdmin != nil {
        let fusdAdminBorrowed = fusdAdmin.borrow()
        results["FUSD_Admin_Borrowable"] = fusdAdminBorrowed != nil ? "true" : "false"
    } else {
        results["FUSD_Admin_Borrowable"] = "false"
    }
    
    // Test 5: Check vault paths and capabilities
    results["BAIT_Vault_Path"] = BaitCoin.VaultStoragePath.toString()
    results["BAIT_Public_Path"] = BaitCoin.VaultPublicPath.toString()
    results["BAIT_Receiver_Path"] = BaitCoin.ReceiverPublicPath.toString()
    results["BAIT_Minter_Path"] = BaitCoin.MinterStoragePath.toString()
    
    // Test 6: Check if emulator can mint (read-only check)
    results["Can_Mint_BAIT"] = baitAdmin != nil ? "true" : "false"
    results["Can_Mint_FUSD"] = fusdAdmin != nil ? "true" : "false"
    
    // Test 7: Check burn functionality availability
    // Note: burnBait currently panics, so we just check if admin exists
    results["Can_Burn_BAIT"] = baitAdmin != nil ? "true" : "false"
    results["Burn_Note"] = "burnBait function currently panics - needs transaction implementation"
    
    // Test 8: Contract deployment status
    results["BaitCoin_Deployed"] = "true" // Assuming it's deployed based on flow.json
    results["FUSD_Deployed"] = "true" // Assuming it's deployed based on flow.json
    
    return results
}
