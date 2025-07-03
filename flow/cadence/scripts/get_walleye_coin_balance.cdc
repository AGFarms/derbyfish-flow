import "FungibleToken"
import "WalleyeCoin"
import "FungibleTokenMetadataViews"

access(all) fun main(address: Address): UFix64 {
    let vaultData = WalleyeCoin.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
        ?? panic("Could not get FTVaultData view for the WalleyeCoin contract")

    return getAccount(address).capabilities.borrow<&{FungibleToken.Balance}>(
            vaultData.metadataPath
        )?.balance
        ?? panic("Could not borrow a reference to the WalleyeCoin Vault in account "
            .concat(address.toString()).concat(" at path ").concat(vaultData.metadataPath.toString())
            .concat(". Make sure you are querying an address that has an WalleyeCoin Vault set up properly."))
}

