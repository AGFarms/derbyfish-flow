import "WalleyeCoin"

// Get ALL WalleyeCoin metadata - comprehensive species and contract information
// Usage: flow scripts execute cadence/scripts/get_walleye_coin_all_metadata.cdc

access(all) fun main(): {String: AnyStruct} {
    
    // Basic contract and token information
    let basicInfo = WalleyeCoin.getBasicInfo()
    let registryInfo = WalleyeCoin.getRegistryInfo()
    let supplyMetrics = WalleyeCoin.getSupplyMetrics()
    
    // Detailed species information
    let conservationInfo = WalleyeCoin.getConservationInfo()
    let biologicalInfo = WalleyeCoin.getBiologicalInfo()
    let anglingInfo = WalleyeCoin.getAnglingInfo()
    let recordInfo = WalleyeCoin.getRecordInfo()
    
    // Regional data - check available regions first
    let availableRegions = WalleyeCoin.getRegionsWithData()
    var regionalData: {String: {String: AnyStruct?}} = {}
    for region in availableRegions {
        regionalData[region] = WalleyeCoin.getRegionalInfo(region: region)
    }
    
    // Temporal and administrative data
    let currentYear = WalleyeCoin.getCurrentYear()
    let availableYears = WalleyeCoin.getAvailableYears()
    let dataCompleteness = WalleyeCoin.getDataCompleteness()
    let pendingUpdates = WalleyeCoin.getPendingUpdates()
    
    // FishDEX integration status
    let fishDEXAddress = WalleyeCoin.getFishDEXAddress()
    let fishDEXRegistered = WalleyeCoin.getFishDEXRegistrationStatus()
    
    // Exchange and economy data
    let baitExchangeRate = WalleyeCoin.getBaitExchangeRate()
    let conservationTier = WalleyeCoin.getConservationTier()
    let isEndangered = WalleyeCoin.isEndangered()
    
    // Data quality metrics
    let hasCompleteMetadata = WalleyeCoin.hasCompleteMetadata()
    let catchCount = WalleyeCoin.getCatchCount()
    
    // Get complete species metadata for additional fields
    let fullMetadata = WalleyeCoin.getSpeciesMetadata()
    
    return {
        "contractOverview": {
            "basicInfo": basicInfo,
            "registryInfo": registryInfo,
            "supplyMetrics": supplyMetrics,
            "totalCatches": catchCount,
            "currentYear": currentYear,
            "dataCompleteness": dataCompleteness,
            "hasCompleteMetadata": hasCompleteMetadata
        },
        
        "speciesProfile": {
            "conservation": conservationInfo,
            "biological": biologicalInfo,
            "angling": anglingInfo,
            "records": recordInfo,
            "conservationTier": conservationTier,
            "isEndangered": isEndangered
        },
        
        "regionalData": {
            "availableRegions": availableRegions,
            "regionDetails": regionalData
        },
        
        "economicData": {
            "baitExchangeRate": baitExchangeRate,
            "regionalCommercialValue": fullMetadata.regionalCommercialValue,
            "tourismValue": fullMetadata.tourismValue,
            "ecosystemRole": fullMetadata.ecosystemRole,
            "culturalSignificance": fullMetadata.culturalSignificance
        },
        
        "physicalTraits": {
            "averageWeight": fullMetadata.averageWeight,
            "averageLength": fullMetadata.averageLength,
            "physicalDescription": fullMetadata.physicalDescription,
            "behaviorTraits": fullMetadata.behaviorTraits,
            "seasonalPatterns": fullMetadata.seasonalPatterns
        },
        
        "habitatData": {
            "habitat": fullMetadata.habitat,
            "nativeRegions": fullMetadata.nativeRegions,
            "currentRange": fullMetadata.currentRange,
            "waterTypes": fullMetadata.waterTypes,
            "invasiveStatus": fullMetadata.invasiveStatus,
            "temperatureRange": fullMetadata.temperatureRange,
            "depthRange": fullMetadata.depthRange,
            "waterQualityNeeds": fullMetadata.waterQualityNeeds
        },
        
        "reproductionData": {
            "spawningAge": fullMetadata.spawningAge,
            "spawningBehavior": fullMetadata.spawningBehavior,
            "migrationPattern": fullMetadata.migrationPattern,
            "lifespan": fullMetadata.lifespan
        },
        
        "fishDEXIntegration": {
            "fishDEXAddress": fishDEXAddress?.toString(),
            "isRegistered": fishDEXRegistered,
            "contractAddress": (registryInfo["contractAddress"]! as! Address).toString()
        },
        
        "researchData": {
            "researchPriority": fullMetadata.researchPriority,
            "geneticMarkers": fullMetadata.geneticMarkers,
            "studyPrograms": fullMetadata.studyPrograms,
            "firstCatchDate": fullMetadata.firstCatchDate
        },
        
        "communityData": {
            "pendingUpdates": pendingUpdates,
            "pendingUpdateCount": pendingUpdates.length,
            "additionalMetadata": fullMetadata.additionalMetadata
        },
        
        "temporalData": {
            "currentYear": currentYear,
            "availableYears": availableYears,
            "dataYear": fullMetadata.dataYear,
            "hasHistoricalData": availableYears.length > 1
        },
        
        "summary": {
            "speciesCode": fullMetadata.speciesCode,
            "ticker": fullMetadata.ticker,
            "commonName": fullMetadata.commonName,
            "scientificName": fullMetadata.scientificName,
            "family": fullMetadata.family,
            "description": fullMetadata.description,
            "imageURL": fullMetadata.imageURL,
            "totalSupply": supplyMetrics["totalSupply"]!,
            "dataQualityScore": dataCompleteness,
            "conservationStatus": fullMetadata.globalConservationStatus,
            "rarityTier": fullMetadata.rarityTier
        }
    }
} 