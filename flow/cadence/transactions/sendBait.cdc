import FungibleToken from 0xf233dcee88fe0abe
import BaitCoin from 0xed2202de80195438

transaction(to: Address, amount: UFix64) {

    prepare(sender: auth(BorrowValue, Storage) &Account) {
        let senderVault = sender.storage.borrow<auth(FungibleToken.Withdraw) &BaitCoin.Vault>(from: /storage/baitCoinVault)
            ?? panic("Could not borrow sender's BAIT vault")

        let recipient = getAccount(to)
        let recipientReceiver = recipient.capabilities.get<&{FungibleToken.Receiver}>(/public/baitCoinReceiver)
            .borrow() ?? panic("Could not borrow recipient's BAIT receiver reference")

        let baitVault <- senderVault.withdraw(amount: amount)
        recipientReceiver.deposit(from: <-baitVault)
    }
}
