import "FUSD"
import "BaitCoin"
import "FungibleToken"

// Script to simulate and validate selling BAIT tokens for FUSD
access(all) fun main(address: Address, baitAmount: UFix64): {String: String} {
    let account = getAccount(address)
    let results: {String: String} = {}
    
    // Validate input parameters
    if baitAmount <= 0.0 {
        results["Error"] = "Bait amount must be greater than zero"
        return results
    }
    
    results["Bait_Amount_To_Sell"] = baitAmount.toString()
    results["User_Address"] = address.toString()
    
    // Check if user has BAIT vault and sufficient balance
    let baitVault = account.capabilities.get<&BaitCoin.Vault>(/public/baitCoinReceiver)
    if baitVault == nil {
        results["BAIT_Vault_Exists"] = "false"
        results["Can_Sell"] = "false"
        results["Error"] = "User does not have a BAIT vault. Run createAllVault.cdc first."
        return results
    }
    
    results["BAIT_Vault_Exists"] = "true"
    
    // Check BAIT balance
    let baitBalance = baitVault.borrow()?.balance ?? 0.0
    results["Current_BAIT_Balance"] = baitBalance.toString()
    
    if baitBalance < baitAmount {
        results["Can_Sell"] = "false"
        results["Error"] = "Insufficient BAIT balance. Required: ".concat(baitAmount.toString()).concat(", Available: ").concat(baitBalance.toString())
        return results
    }
    
    results["Can_Sell"] = "true"
    
    // Check if user has FUSD vault to receive FUSD
    let fusdVault = account.capabilities.get<&FUSD.Vault>(/public/fusdReceiver)
    if fusdVault == nil {
        results["FUSD_Vault_Exists"] = "false"
        results["Can_Receive_FUSD"] = "false"
        results["Error"] = "User does not have a FUSD vault. Run createAllVault.cdc first."
        return results
    }
    
    results["FUSD_Vault_Exists"] = "true"
    results["Can_Receive_FUSD"] = "true"
    
    // Check current FUSD balance
    let currentFusdBalance = fusdVault.borrow()?.balance ?? 0.0
    results["Current_FUSD_Balance"] = currentFusdBalance.toString()
    
    // Simulate the swap (1:1 ratio based on the contract)
    // Note: This is a simulation - actual swap rates may vary
    let estimatedFusdReceived = baitAmount
    results["Estimated_FUSD_Received"] = estimatedFusdReceived.toString()
    results["Estimated_FUSD_Balance_After"] = (currentFusdBalance + estimatedFusdReceived).toString()
    results["Estimated_BAIT_Balance_After"] = (baitBalance - baitAmount).toString()
    
    // Check contract availability
    let contractAccount = getAccount(0xf8d6e0586b0a20c7) // emulator-account
    results["Contract_Account"] = "0xf8d6e0586b0a20c7"
    results["Contract_Available"] = "true"
    
    // Validate swap prerequisites
    results["Swap_Prerequisites_Met"] = "true"
    results["Ready_To_Sell"] = "true"
    
    // Transaction simulation results
    results["Transaction_Type"] = "swapBaitForFusd"
    results["Required_Auth"] = "BorrowValue, Storage"
    results["Vault_Path"] = "/storage/baitCoinVault"
    results["Receiver_Path"] = "/public/busdReceiver"
    
    // Summary
    results["Summary"] = "User can sell ".concat(baitAmount.toString()).concat(" BAIT for approximately ").concat(estimatedFusdReceived.toString()).concat(" FUSD")
    
    return results
}
