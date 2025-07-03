import "ExampleFishCoin"
import "WalleyeCoin"

transaction(ticker: String) {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {
        if ticker == "EXFISH" {
            if signer.storage.borrow<&ExampleFishCoin.Vault>(from: ExampleFishCoin.VaultStoragePath) == nil {
                let vault <- ExampleFishCoin.createEmptyVault(vaultType: Type<@ExampleFishCoin.Vault>())
                signer.storage.save(<-vault, to: ExampleFishCoin.VaultStoragePath)
            }
            if signer.capabilities.get<&ExampleFishCoin.Vault>(ExampleFishCoin.VaultPublicPath) == nil {
                let vaultCap = signer.capabilities.storage.issue<&ExampleFishCoin.Vault>(
                    ExampleFishCoin.VaultStoragePath
                )
                signer.capabilities.publish(vaultCap, at: ExampleFishCoin.VaultPublicPath)
            }
        } else if ticker == "SANVIT" {
            if signer.storage.borrow<&WalleyeCoin.Vault>(from: WalleyeCoin.VaultStoragePath) == nil {
                let vault <- WalleyeCoin.createEmptyVault(vaultType: Type<@WalleyeCoin.Vault>())
                signer.storage.save(<-vault, to: WalleyeCoin.VaultStoragePath)
            }
            if signer.capabilities.get<&WalleyeCoin.Vault>(WalleyeCoin.VaultPublicPath) == nil {
                let vaultCap = signer.capabilities.storage.issue<&WalleyeCoin.Vault>(
                    WalleyeCoin.VaultStoragePath
                )
                signer.capabilities.publish(vaultCap, at: WalleyeCoin.VaultPublicPath)
            }
        } else {
            panic("Unsupported ticker: ".concat(ticker))
        }
    }
    execute {}
}