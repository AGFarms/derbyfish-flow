import BaitCoin from 0xed2202de80195438

access(all) fun main(address: Address): [String] {
    let account = getAccount(address)
    let capabilities: [String] = []
    
    // Check for BAIT vault capability
    let vaultCapability = account.capabilities.get<&BaitCoin.Vault>(BaitCoin.VaultPublicPath)
    if vaultCapability != nil {
        capabilities.append("BAIT Vault: " + BaitCoin.VaultPublicPath.toString())
    }
    
    // Check for BAIT receiver capability  
    let receiverCapability = account.capabilities.get<&{FungibleToken.Receiver}>(BaitCoin.ReceiverPublicPath)
    if receiverCapability != nil {
        capabilities.append("BAIT Receiver: " + BaitCoin.ReceiverPublicPath.toString())
    }
    
    // Check for balance capability
    let balanceCapability = account.capabilities.get<&{FungibleToken.Balance}>(BaitCoin.VaultPublicPath)
    if balanceCapability != nil {
        capabilities.append("BAIT Balance: " + BaitCoin.VaultPublicPath.toString())
    }
    
    return capabilities
}
