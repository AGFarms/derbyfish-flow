import "FungibleToken"
import "WalleyeCoin"
import "FungibleTokenMetadataViews"

// Get comprehensive WalleyeCoin information including contract metadata
// Usage: flow scripts execute cadence/scripts/get_walleye_coin_info.cdc <address>

access(all) fun main(address: Address): {String: AnyStruct} {
    
    // Get vault data for path information
    let vaultData = WalleyeCoin.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
        ?? panic("Could not get FTVaultData view for the WalleyeCoin contract")
    
    // Get user's balance
    let balance = getAccount(address).capabilities.borrow<&{FungibleToken.Balance}>(
            vaultData.metadataPath
        )?.balance ?? 0.0
    
    // Check if account has vault set up
    let hasVault = getAccount(address).capabilities.borrow<&{FungibleToken.Balance}>(
            vaultData.metadataPath
        ) != nil
    
    // Get WalleyeCoin contract information using built-in functions
    let basicInfo = WalleyeCoin.getBasicInfo()
    let registryInfo = WalleyeCoin.getRegistryInfo()
    let speciesMetadata = WalleyeCoin.getSpeciesMetadata()
    let totalSupply = WalleyeCoin.getTotalSupply()
    
    return {
        "success": true,
        "accountAddress": address.toString(),
        "tokenInfo": basicInfo,
        "speciesInfo": {
            "commonName": speciesMetadata.commonName,
            "scientificName": speciesMetadata.scientificName,
            "family": speciesMetadata.family,
            "habitat": speciesMetadata.habitat,
            "description": speciesMetadata.description,
            "conservationStatus": speciesMetadata.globalConservationStatus,
            "rarityTier": speciesMetadata.rarityTier,
            "averageWeight": speciesMetadata.averageWeight,
            "averageLength": speciesMetadata.averageLength,
            "imageURL": speciesMetadata.imageURL
        },
        "vaultInfo": {
            "storagePath": vaultData.storagePath.toString(),
            "metadataPath": vaultData.metadataPath.toString(), 
            "receiverPath": vaultData.receiverPath.toString()
        },
        "accountBalance": {
            "balance": balance,
            "hasVaultSetup": hasVault
        },
        "contractInfo": {
            "totalSupply": totalSupply,
            "contractAddress": (registryInfo["contractAddress"]! as! Address).toString(),
            "fishDEXRegistered": registryInfo["isRegistered"]! as! Bool,
            "fishDEXAddress": WalleyeCoin.getFishDEXAddress()?.toString()
        },
        "registryInfo": registryInfo,
        "testingNotes": {
            "message": hasVault ? 
                "Account properly set up for WalleyeCoin" : 
                "Account needs WalleyeCoin vault setup",
            "setupCommand": hasVault ? 
                "No setup needed" : 
                "flow transactions send cadence/transactions/setup_walleye_coin_account.cdc --signer <account>"
        }
    }
} 