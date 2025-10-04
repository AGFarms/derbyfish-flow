import "FlowToken"
import "FungibleToken"

// Transaction to fund a wallet with FLOW tokens
transaction(recipient: Address, amount: UFix64) {
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault) ?? panic("Could not borrow FlowToken vault")
        let tokens <- vault.withdraw(amount: amount)
        let recipient = getAccount(recipient)
        let receiver = recipient.capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        if receiver == nil {
            panic("Could not borrow FlowToken receiver")
        }
        receiver!.borrow()!.deposit(from: <-tokens)
    }
    execute {
        log("Transferred ".concat(amount.toString()).concat(" FLOW tokens").concat(" to ").concat(recipient.toString()))
    }
}
