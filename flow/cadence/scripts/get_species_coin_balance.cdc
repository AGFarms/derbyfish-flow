import "ExampleFishCoin"
import "WalleyeCoin"
import "FungibleToken"
import "FungibleTokenMetadataViews"

access(all) fun main(address: Address, ticker: String): UFix64 {
    if ticker == "EXFISH" {
        let vaultData = ExampleFishCoin.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
            ?? panic("Could not get FTVaultData for ExampleFishCoin")
        return getAccount(address).capabilities.borrow<&{FungibleToken.Balance}>(vaultData.metadataPath)?.balance
            ?? panic("No ExampleFishCoin vault at ".concat(vaultData.metadataPath.toString()))
    } else if ticker == "SANVIT" {
        let vaultData = WalleyeCoin.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
            ?? panic("Could not get FTVaultData for WalleyeCoin")
        return getAccount(address).capabilities.borrow<&{FungibleToken.Balance}>(vaultData.metadataPath)?.balance
            ?? panic("No WalleyeCoin vault at ".concat(vaultData.metadataPath.toString()))
    }
    panic("Unsupported ticker: ".concat(ticker))
}

// Test/demo usage (for documentation only, not executed by Flow CLI):
// Uncomment and replace the address with your test account to try locally in Cadence playgrounds or for reference.
//
// pub fun test() {
//     let testAcct: Address = 0x01cf0e2f2f715450 // Replace with your test account address
//     let ticker: String = "SANVIT" // WalleyeCoin ticker
//     let balance = main(testAcct, ticker)
//     log(balance)
// }