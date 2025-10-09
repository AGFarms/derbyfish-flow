import FungibleToken from 0xf233dcee88fe0abe
import BaitCoin from 0xed2202de80195438

access(all) fun main(address: Address): UFix64 {
    let account = getAccount(address)
    
    // Try to get the balance capability using the FungibleToken.Balance interface
    let balanceCapability = account.capabilities.get<&{FungibleToken.Balance}>(BaitCoin.VaultPublicPath)
    
    if balanceCapability == nil {
        panic("BaitCoin balance capability not found")
    }
    
    let balanceRef = balanceCapability!.borrow()
    if balanceRef == nil {
        panic("Could not borrow BaitCoin balance reference")
    }
    
    return balanceRef!.balance
}
