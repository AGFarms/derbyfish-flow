import FungibleToken from 0xf233dcee88fe0abe
import BaitCoin from 0xed2202de80195438

access(all) fun main(address: Address): UFix64 {
    let account = getAccount(address)
    
    // Try to get the vault capability using the FungibleToken.Balance interface
    let vaultCapability = account.capabilities.get<&{FungibleToken.Balance}>(BaitCoin.VaultPublicPath)
    
    if vaultCapability == nil {
        // If that doesn't work, try getting the full vault capability
        let fullVaultCapability = account.capabilities.get<&BaitCoin.Vault>(BaitCoin.VaultPublicPath)
        if fullVaultCapability == nil {
            return 0.0
        }
        let vaultRef = fullVaultCapability!.borrow()
        if vaultRef == nil {
            return 0.0
        }
        return vaultRef!.balance
    }
    
    let vaultRef = vaultCapability!.borrow()
    
    return vaultRef!.balance
}
