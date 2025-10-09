import FlowToken from 0x1654653399040a61
import FungibleToken from 0xf233dcee88fe0abe

access(all) fun main(address: Address): UFix64 {
    let account = getAccount(address)
    
    // Try to get the balance capability using the FungibleToken.Balance interface
    let balanceCapability = account.capabilities.get<&{FungibleToken.Balance}>(/public/flowTokenBalance)
    
    if balanceCapability == nil {
        panic("FlowToken balance capability not found")
    }
    
    let balanceRef = balanceCapability!.borrow()
    if balanceRef == nil {
        panic("Could not borrow FlowToken balance reference")
    }
    
    return balanceRef!.balance
}
