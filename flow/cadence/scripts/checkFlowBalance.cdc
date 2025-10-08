import FlowToken from 0x1654653399040a61

access(all) fun main(address: Address): UFix64 {
    let account = getAccount(address)
    
    // Try to get the vault capability using the FungibleToken.Balance interface
    let vaultCapability = account.capabilities.get<&{FlowToken.Vault}>(/public/flowTokenVault)
    
    if vaultCapability == nil {
        return 0.0
    }
    
    let vaultRef = vaultCapability!.borrow()
    if vaultRef == nil {
        return 0.0
    }
    
    return vaultRef!.balance
}
