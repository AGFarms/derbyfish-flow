import "BaitCoin"

// Script to get the FUSD balance stored in the BaitCoin contract
access(all) fun main(): UFix64 {
    return BaitCoin.getContractFUSDBalance()
}