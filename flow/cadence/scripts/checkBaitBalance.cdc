import "FungibleToken"
import "BaitCoin"

access(all) fun main(address: Address): UFix64 {
    let account = getAccount(address)
    
    // Get the BAIT vault capability from the correct path
    let baitVault = account.capabilities.get<&BaitCoin.Vault>(/public/baitCoinReceiver)
    
    if baitVault == nil {
        panic("Could not get BAIT vault capability for account ".concat(address.toString()).concat(". Make sure the account has a BAIT vault set up properly."))
    }
    
    // Borrow the vault and get the balance
    return baitVault.borrow()?.balance ?? panic("Could not borrow BAIT vault reference for account ".concat(address.toString()))
}
