import "BaitCoin"

access(all) fun main(): String {
    log("Checking FlowToken vault...")
    log(Type<@BaitCoin.Vault>().identifier)
    return Type<@BaitCoin.Vault>().identifier
}
