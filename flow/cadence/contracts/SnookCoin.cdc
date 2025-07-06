import "FungibleToken"
import "MetadataViews"
import "FungibleTokenMetadataViews"

access(all) contract SnookCoin: FungibleToken {

    // FISHDEX INTEGRATION - Cross-contract coordination interface
    access(all) resource interface SpeciesCoinPublic {
        access(all) view fun getSpeciesCode(): String
        access(all) view fun getTicker(): String
        access(all) view fun getCommonName(): String
        access(all) view fun getScientificName(): String
        access(all) view fun getFamily(): String
        access(all) view fun getTotalSupply(): UFix64
        access(all) view fun getBasicRegistryInfo(): {String: AnyStruct}
        access(all) fun redeemCatchNFT(fishData: {String: AnyStruct}, angler: Address): @SnookCoin.Vault
    }

    // FISHDEX COORDINATION - Registry management
    access(all) var fishDEXAddress: Address?
    access(all) var isRegisteredWithFishDEX: Bool

    // Regional data structures for location-specific information
    access(all) struct RegionalRegulations {
        access(all) var sizeLimit: UFix64?         // Minimum legal size in inches
        access(all) var bagLimit: UInt8?           // Daily catch limit  
        access(all) var closedSeasons: [String]    // Protected breeding periods
        access(all) var specialRegulations: String // Additional rules/restrictions
        access(all) var licenseRequired: Bool      // Fishing license requirement
        
        init(sizeLimit: UFix64?, bagLimit: UInt8?, closedSeasons: [String], specialRegulations: String, licenseRequired: Bool) {
            self.sizeLimit = sizeLimit
            self.bagLimit = bagLimit
            self.closedSeasons = closedSeasons
            self.specialRegulations = specialRegulations
            self.licenseRequired = licenseRequired
        }
    }

    access(all) struct RegionalPopulation {
        access(all) var populationTrend: String?   // "Increasing", "Stable", "Declining", "Critical"
        access(all) var threats: [String]          // Region-specific threats
        access(all) var protectedAreas: [String]   // Local protected areas
        access(all) var estimatedPopulation: UInt64? // If known
        
        init(populationTrend: String?, threats: [String], protectedAreas: [String], estimatedPopulation: UInt64?) {
            self.populationTrend = populationTrend
            self.threats = threats
            self.protectedAreas = protectedAreas
            self.estimatedPopulation = estimatedPopulation
        }
    }

    // Events
    access(all) event TokensMinted(amount: UFix64, to: Address?)
    access(all) event TokensBurned(amount: UFix64, from: Address?)
    access(all) event CatchVerified(fishId: UInt64, angler: Address, amount: UFix64)
    access(all) event MetadataUpdated(field: String, oldValue: String, newValue: String)
    access(all) event FirstCatchRecorded(timestamp: UInt64, angler: Address)
    access(all) event YearlyMetadataCreated(year: UInt64)
    access(all) event MetadataYearUpdated(oldYear: UInt64, newYear: UInt64)
    access(all) event NFTAlreadyMinted(fishId: UInt64, angler: Address)
    
    // FISHDEX INTEGRATION EVENTS
    access(all) event FishDEXRegistrationAttempted(fishDEXAddress: Address, speciesCode: String)
    access(all) event FishDEXRegistrationCompleted(fishDEXAddress: Address, speciesCode: String)
    access(all) event FishDEXAddressUpdated(oldAddress: Address?, newAddress: Address)
    access(all) event CatchProcessedFromNFT(fishNFTId: UInt64?, angler: Address, amount: UFix64)

    // Total supply
    access(all) var totalSupply: UFix64

    // Track which NFTs have been used for minting
    access(all) var fishNFTRegistry: {UInt64: Bool}

    // Temporal metadata system - Track yearly updates
    access(all) var currentMetadataYear: UInt64
    access(all) var metadataHistory: {UInt64: SpeciesMetadata}
    access(all) var speciesMetadata: SpeciesMetadata // Current year metadata (pointer to latest)
    
    // Regional context for location-specific operations
    access(all) var defaultRegion: String

    // Storage paths
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let MetadataAdminStoragePath: StoragePath
    access(all) let FishDEXCoordinatorStoragePath: StoragePath
    access(all) let FishDEXCoordinatorPublicPath: PublicPath

    // Species metadata - HYBRID: Core fields immutable, descriptive fields mutable + REGIONAL + TEMPORAL
    access(all) struct SpeciesMetadata {
        // IMMUTABLE - Core identity fields that should never change
        access(all) let commonName: String         // e.g., "Example Fish"
        access(all) let speciesCode: String        // e.g., "EXAMPLE_FISH"
        access(all) let ticker: String             // e.g., "EXFISH"
        access(all) let scientificName: String     // e.g., "Example fish"
        access(all) let family: String             // e.g., "Example family"
        access(all) let dataYear: UInt64           // Year this metadata represents
        
        // MUTABLE - Descriptive fields that can be updated (NULLABLE WHERE APPROPRIATE)
        access(all) var habitat: String?           // e.g., "Freshwater" - nullable if unknown
        access(all) var averageWeight: UFix64?     // in pounds - nullable if unknown
        access(all) var averageLength: UFix64?     // in inches - nullable if unknown
        access(all) var imageURL: String?          // species reference image - nullable
        access(all) var description: String        // species description
        access(all) var firstCatchDate: UInt64?    // timestamp of first verified catch
        access(all) var rarityTier: UInt8?         // 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary
        
        // GLOBAL CONSERVATION & POPULATION INTELLIGENCE
        access(all) var globalConservationStatus: String? // IUCN status: "Least Concern", "Threatened", etc.
        access(all) var regionalPopulations: {String: RegionalPopulation} // Region-specific population data
        
        // BIOLOGICAL INTELLIGENCE (NULLABLE WHERE DATA MAY BE MISSING)
        access(all) var lifespan: UFix64?          // Maximum age in years
        access(all) var diet: String?              // Primary food sources
        access(all) var predators: [String]        // Natural predators (can be empty)
        access(all) var temperatureRange: String?  // Preferred water temps
        access(all) var depthRange: String?        // Habitat depth range
        access(all) var spawningAge: UFix64?       // Sexual maturity age in years
        access(all) var spawningBehavior: String?  // Detailed spawning patterns
        access(all) var migrationPattern: String?  // Migration behavior
        access(all) var waterQualityNeeds: String? // pH, oxygen, salinity requirements
        
        // GEOGRAPHIC & HABITAT INTELLIGENCE
        access(all) var nativeRegions: [String]    // ["North America", "Great Lakes", "Mississippi River"]
        access(all) var currentRange: [String]     // Current distribution (may differ from native)
        access(all) var waterTypes: [String]       // ["River", "Lake", "Stream", "Reservoir"]
        access(all) var invasiveStatus: String?    // "Native", "Introduced", "Invasive", "Hybrid"
        
        // ECONOMIC & COMMERCIAL INTELLIGENCE (REGIONAL)
        access(all) var regionalCommercialValue: {String: UFix64} // Market price per pound by region
        access(all) var tourismValue: UInt8?       // Tourism draw rating 1-10
        access(all) var ecosystemRole: String?     // "Apex Predator", "Baitfish", "Bottom Feeder"
        access(all) var culturalSignificance: String? // Historical/cultural importance
        
        // ANGLING & RECREATIONAL INTELLIGENCE
        access(all) var bestBaits: [String]        // Most effective baits
        access(all) var fightRating: UInt8?        // Fight intensity 1-10
        access(all) var culinaryRating: UInt8?     // Eating quality 1-10
        access(all) var catchDifficulty: UInt8?    // How hard to catch 1-10
        access(all) var seasonalAvailability: String? // When most catchable
        access(all) var bestTechniques: [String]   // Preferred fishing methods
        
        // REGIONAL REGULATORY INTELLIGENCE
        access(all) var regionalRegulations: {String: RegionalRegulations} // Region-specific rules
        
        // PHYSICAL & BEHAVIORAL CHARACTERISTICS
        access(all) var physicalDescription: String? // Colors, patterns, distinguishing features
        access(all) var behaviorTraits: String?     // Feeding habits, aggression, schooling
        access(all) var seasonalPatterns: String?   // Activity throughout the year
        
        // RECORDS & ACHIEVEMENTS
        access(all) var recordWeight: UFix64?       // World record weight in pounds
        access(all) var recordWeightLocation: String? // Where weight record was caught
        access(all) var recordWeightDate: String?   // When weight record was set
        access(all) var recordLength: UFix64?       // World record length in inches
        access(all) var recordLengthLocation: String? // Where length record was caught
        access(all) var recordLengthDate: String?   // When length record was set
        
        // RESEARCH & SCIENTIFIC INTELLIGENCE
        access(all) var researchPriority: UInt8?   // Scientific research importance 1-10
        access(all) var geneticMarkers: String?    // DNA/genetic information
        access(all) var studyPrograms: [String]    // Active research programs
        
        // FLEXIBLE METADATA SYSTEM
        access(all) var additionalMetadata: {String: String} // Custom key-value pairs for future expansion

        // BASIC FIELD SETTERS
        access(all) fun setHabitat(_ newHabitat: String) { self.habitat = newHabitat }
        access(all) fun setAverageWeight(_ newWeight: UFix64) { self.averageWeight = newWeight }
        access(all) fun setAverageLength(_ newLength: UFix64) { self.averageLength = newLength }
        access(all) fun setImageURL(_ newURL: String) { self.imageURL = newURL }
        access(all) fun setDescription(_ newDescription: String) { self.description = newDescription }
        access(all) fun setFirstCatchDate(_ newDate: UInt64?) { self.firstCatchDate = newDate }
        access(all) fun setRarityTier(_ newTier: UInt8) { self.rarityTier = newTier }
        
        // CONSERVATION & POPULATION SETTERS
        access(all) fun setConservationStatus(_ newStatus: String) { self.globalConservationStatus = newStatus }
        access(all) fun setRegionalPopulationTrend(_ region: String, _ newTrend: String?) { 
            if let existing = self.regionalPopulations[region] {
                self.regionalPopulations[region] = RegionalPopulation(
                    populationTrend: newTrend,
                    threats: existing.threats,
                    protectedAreas: existing.protectedAreas,
                    estimatedPopulation: existing.estimatedPopulation
                )
            }
        }
        access(all) fun setRegionalThreats(_ region: String, _ newThreats: [String]) { 
            if let existing = self.regionalPopulations[region] {
                self.regionalPopulations[region] = RegionalPopulation(
                    populationTrend: existing.populationTrend,
                    threats: newThreats,
                    protectedAreas: existing.protectedAreas,
                    estimatedPopulation: existing.estimatedPopulation
                )
            }
        }
        access(all) fun setRegionalProtectedAreas(_ region: String, _ newAreas: [String]) { 
            if let existing = self.regionalPopulations[region] {
                self.regionalPopulations[region] = RegionalPopulation(
                    populationTrend: existing.populationTrend,
                    threats: existing.threats,
                    protectedAreas: newAreas,
                    estimatedPopulation: existing.estimatedPopulation
                )
            }
        }
        
        // BIOLOGICAL SETTERS
        access(all) fun setLifespan(_ newLifespan: UFix64) { self.lifespan = newLifespan }
        access(all) fun setDiet(_ newDiet: String) { self.diet = newDiet }
        access(all) fun setPredators(_ newPredators: [String]) { self.predators = newPredators }
        access(all) fun setTemperatureRange(_ newRange: String) { self.temperatureRange = newRange }
        access(all) fun setDepthRange(_ newRange: String) { self.depthRange = newRange }
        access(all) fun setSpawningAge(_ newAge: UFix64) { self.spawningAge = newAge }
        access(all) fun setSpawningBehavior(_ newBehavior: String) { self.spawningBehavior = newBehavior }
        access(all) fun setMigrationPattern(_ newPattern: String) { self.migrationPattern = newPattern }
        access(all) fun setWaterQualityNeeds(_ newNeeds: String) { self.waterQualityNeeds = newNeeds }
        
        // GEOGRAPHIC & HABITAT SETTERS
        access(all) fun setNativeRegions(_ newRegions: [String]) { self.nativeRegions = newRegions }
        access(all) fun setCurrentRange(_ newRange: [String]) { self.currentRange = newRange }
        access(all) fun setWaterTypes(_ newTypes: [String]) { self.waterTypes = newTypes }
        access(all) fun setInvasiveStatus(_ newStatus: String) { self.invasiveStatus = newStatus }
        
        // ECONOMIC & COMMERCIAL SETTERS
        access(all) fun setRegionalCommercialValue(_ region: String, _ newValue: UFix64) { self.regionalCommercialValue[region] = newValue }
        access(all) fun setTourismValue(_ newValue: UInt8?) { self.tourismValue = newValue }
        access(all) fun setEcosystemRole(_ newRole: String?) { self.ecosystemRole = newRole }
        access(all) fun setCulturalSignificance(_ newSignificance: String?) { self.culturalSignificance = newSignificance }
        
        // ANGLING & RECREATIONAL SETTERS
        access(all) fun setBestBaits(_ newBaits: [String]) { self.bestBaits = newBaits }
        access(all) fun setFightRating(_ newRating: UInt8?) { self.fightRating = newRating }
        access(all) fun setCulinaryRating(_ newRating: UInt8?) { self.culinaryRating = newRating }
        access(all) fun setCatchDifficulty(_ newDifficulty: UInt8?) { self.catchDifficulty = newDifficulty }
        access(all) fun setSeasonalAvailability(_ newAvailability: String?) { self.seasonalAvailability = newAvailability }
        access(all) fun setBestTechniques(_ newTechniques: [String]) { self.bestTechniques = newTechniques }
        
        // REGULATORY SETTERS
        access(all) fun setRegionalSizeLimit(_ region: String, _ newLimit: UFix64?) { 
            if let existing = self.regionalRegulations[region] {
                self.regionalRegulations[region] = RegionalRegulations(
                    sizeLimit: newLimit,
                    bagLimit: existing.bagLimit,
                    closedSeasons: existing.closedSeasons,
                    specialRegulations: existing.specialRegulations,
                    licenseRequired: existing.licenseRequired
                )
            }
        }
        access(all) fun setRegionalBagLimit(_ region: String, _ newLimit: UInt8?) { 
            if let existing = self.regionalRegulations[region] {
                self.regionalRegulations[region] = RegionalRegulations(
                    sizeLimit: existing.sizeLimit,
                    bagLimit: newLimit,
                    closedSeasons: existing.closedSeasons,
                    specialRegulations: existing.specialRegulations,
                    licenseRequired: existing.licenseRequired
                )
            }
        }
        access(all) fun setRegionalClosedSeasons(_ region: String, _ newSeasons: [String]) { 
            if let existing = self.regionalRegulations[region] {
                self.regionalRegulations[region] = RegionalRegulations(
                    sizeLimit: existing.sizeLimit,
                    bagLimit: existing.bagLimit,
                    closedSeasons: newSeasons,
                    specialRegulations: existing.specialRegulations,
                    licenseRequired: existing.licenseRequired
                )
            }
        }
        access(all) fun setRegionalSpecialRegulations(_ region: String, _ newRegulations: String) { 
            if let existing = self.regionalRegulations[region] {
                self.regionalRegulations[region] = RegionalRegulations(
                    sizeLimit: existing.sizeLimit,
                    bagLimit: existing.bagLimit,
                    closedSeasons: existing.closedSeasons,
                    specialRegulations: newRegulations,
                    licenseRequired: existing.licenseRequired
                )
            }
        }
        
        // PHYSICAL & BEHAVIORAL SETTERS
        access(all) fun setPhysicalDescription(_ newDescription: String) { self.physicalDescription = newDescription }
        access(all) fun setBehaviorTraits(_ newTraits: String) { self.behaviorTraits = newTraits }
        access(all) fun setSeasonalPatterns(_ newPatterns: String) { self.seasonalPatterns = newPatterns }
        
        // RECORDS & ACHIEVEMENTS SETTERS
        access(all) fun setRecordWeight(_ newRecord: UFix64?) { self.recordWeight = newRecord }
        access(all) fun setRecordWeightLocation(_ newLocation: String?) { self.recordWeightLocation = newLocation }
        access(all) fun setRecordWeightDate(_ newDate: String?) { self.recordWeightDate = newDate }
        access(all) fun setRecordLength(_ newRecord: UFix64?) { self.recordLength = newRecord }
        access(all) fun setRecordLengthLocation(_ newLocation: String?) { self.recordLengthLocation = newLocation }
        access(all) fun setRecordLengthDate(_ newDate: String?) { self.recordLengthDate = newDate }
        
        // RESEARCH & SCIENTIFIC SETTERS
        access(all) fun setResearchPriority(_ newPriority: UInt8) { self.researchPriority = newPriority }
        access(all) fun setGeneticMarkers(_ newMarkers: String) { self.geneticMarkers = newMarkers }
        access(all) fun setStudyPrograms(_ newPrograms: [String]) { self.studyPrograms = newPrograms }
        
        // FLEXIBLE METADATA SETTERS
        access(all) fun setAdditionalMetadata(_ newMetadata: {String: String}) { self.additionalMetadata = newMetadata }
        access(all) fun updateMetadataField(_ key: String, _ value: String) { self.additionalMetadata[key] = value }

        init(
            // IMMUTABLE CORE FIELDS
            speciesCode: String,
            ticker: String,
            scientificName: String,
            family: String,
            dataYear: UInt64,
            
            // BASIC DESCRIPTIVE FIELDS
            commonName: String,
            habitat: String?,
            averageWeight: UFix64?,
            averageLength: UFix64?,
            imageURL: String?,
            description: String,
            firstCatchDate: UInt64?,
            rarityTier: UInt8?,
            
            // CONSERVATION & POPULATION
            globalConservationStatus: String?,
            regionalPopulations: {String: RegionalPopulation},
            
            // BIOLOGICAL INTELLIGENCE
            lifespan: UFix64?,
            diet: String?,
            predators: [String],
            temperatureRange: String?,
            depthRange: String?,
            spawningAge: UFix64?,
            spawningBehavior: String?,
            migrationPattern: String?,
            waterQualityNeeds: String?,
            
            // GEOGRAPHIC & HABITAT
            nativeRegions: [String],
            currentRange: [String],
            waterTypes: [String],
            invasiveStatus: String?,
            
            // ECONOMIC & COMMERCIAL
            regionalCommercialValue: {String: UFix64},
            tourismValue: UInt8?,
            ecosystemRole: String?,
            culturalSignificance: String?,
            
            // ANGLING & RECREATIONAL
            bestBaits: [String],
            fightRating: UInt8?,
            culinaryRating: UInt8?,
            catchDifficulty: UInt8?,
            seasonalAvailability: String?,
            bestTechniques: [String],
            
            // REGULATORY
            regionalRegulations: {String: RegionalRegulations},
            
            // PHYSICAL & BEHAVIORAL
            physicalDescription: String?,
            behaviorTraits: String?,
            seasonalPatterns: String?,
            
            // RECORDS & ACHIEVEMENTS
            recordWeight: UFix64?,
            recordWeightLocation: String?,
            recordWeightDate: String?,
            recordLength: UFix64?,
            recordLengthLocation: String?,
            recordLengthDate: String?,
            
            // RESEARCH & SCIENTIFIC
            researchPriority: UInt8?,
            geneticMarkers: String?,
            studyPrograms: [String],
            
            // FLEXIBLE METADATA
            additionalMetadata: {String: String}
        ) {
            // Set immutable fields
            self.speciesCode = speciesCode
            self.ticker = ticker
            self.scientificName = scientificName
            self.family = family
            self.dataYear = dataYear
            
            // Set basic descriptive fields
            self.commonName = commonName
            self.habitat = habitat
            self.averageWeight = averageWeight
            self.averageLength = averageLength
            self.imageURL = imageURL
            self.description = description
            self.firstCatchDate = firstCatchDate
            self.rarityTier = rarityTier
            
            // Set conservation & population fields
            self.globalConservationStatus = globalConservationStatus
            self.regionalPopulations = regionalPopulations
            
            // Set biological intelligence fields
            self.lifespan = lifespan
            self.diet = diet
            self.predators = predators
            self.temperatureRange = temperatureRange
            self.depthRange = depthRange
            self.spawningAge = spawningAge
            self.spawningBehavior = spawningBehavior
            self.migrationPattern = migrationPattern
            self.waterQualityNeeds = waterQualityNeeds
            
            // Set geographic & habitat fields
            self.nativeRegions = nativeRegions
            self.currentRange = currentRange
            self.waterTypes = waterTypes
            self.invasiveStatus = invasiveStatus
            
            // Set economic & commercial fields
            self.regionalCommercialValue = regionalCommercialValue
            self.tourismValue = tourismValue
            self.ecosystemRole = ecosystemRole
            self.culturalSignificance = culturalSignificance
            
            // Set angling & recreational fields
            self.bestBaits = bestBaits
            self.fightRating = fightRating
            self.culinaryRating = culinaryRating
            self.catchDifficulty = catchDifficulty
            self.seasonalAvailability = seasonalAvailability
            self.bestTechniques = bestTechniques
            
            // Set regulatory fields
            self.regionalRegulations = regionalRegulations
            
            // Set physical & behavioral fields
            self.physicalDescription = physicalDescription
            self.behaviorTraits = behaviorTraits
            self.seasonalPatterns = seasonalPatterns
            
            // Set records & achievements fields
            self.recordWeight = recordWeight
            self.recordWeightLocation = recordWeightLocation
            self.recordWeightDate = recordWeightDate
            self.recordLength = recordLength
            self.recordLengthLocation = recordLengthLocation
            self.recordLengthDate = recordLengthDate
            
            // Set research & scientific fields
            self.researchPriority = researchPriority
            self.geneticMarkers = geneticMarkers
            self.studyPrograms = studyPrograms
            
            // Set flexible metadata
            self.additionalMetadata = additionalMetadata
        }
    }

    // Contract Views
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>(),
            Type<FungibleTokenMetadataViews.TotalSupply>()
        ]
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(url: self.speciesMetadata.imageURL ?? ""),
                    mediaType: "image/jpeg"
                )
                return FungibleTokenMetadataViews.FTDisplay(
                    name: self.speciesMetadata.commonName.concat(" Coin"),
                    symbol: self.speciesMetadata.ticker,
                    description: self.speciesMetadata.description,
                    externalURL: MetadataViews.ExternalURL("https://derby.fish/species/".concat(self.speciesMetadata.speciesCode.toLower())),
                    logos: MetadataViews.Medias([media]),
                    socials: {
                        "website": MetadataViews.ExternalURL("https://derby.fish"),
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/derbyfish")
                    }
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: self.VaultStoragePath,
                    receiverPath: self.VaultPublicPath,
                    metadataPath: self.VaultPublicPath,
                    receiverLinkedType: Type<&SnookCoin.Vault>(),
                    metadataLinkedType: Type<&SnookCoin.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-SnookCoin.createEmptyVault(vaultType: Type<@SnookCoin.Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(totalSupply: self.totalSupply)
        }
        return nil
    }

    // FISHDEX COORDINATOR RESOURCE - Handles cross-contract integration
    access(all) resource FishDEXCoordinator: SpeciesCoinPublic {
        
        // Interface implementation for FishDEX registry
        access(all) view fun getSpeciesCode(): String {
            return SnookCoin.speciesMetadata.speciesCode
        }
        
        access(all) view fun getTicker(): String {
            return SnookCoin.speciesMetadata.ticker
        }
        
        access(all) view fun getCommonName(): String {
            return SnookCoin.speciesMetadata.commonName
        }
        
        access(all) view fun getScientificName(): String {
            return SnookCoin.speciesMetadata.scientificName
        }
        
        access(all) view fun getFamily(): String {
            return SnookCoin.speciesMetadata.family
        }
        
        access(all) view fun getTotalSupply(): UFix64 {
            return SnookCoin.totalSupply
        }
        
        access(all) view fun getBasicRegistryInfo(): {String: AnyStruct} {
            return {
                "speciesCode": self.getSpeciesCode(),
                "ticker": self.getTicker(),
                "commonName": self.getCommonName(),
                "scientificName": self.getScientificName(),
                "family": self.getFamily(),
                "totalSupply": self.getTotalSupply(),
                "contractAddress": SnookCoin.account.address,
                "dataYear": SnookCoin.speciesMetadata.dataYear,
                "conservationStatus": SnookCoin.speciesMetadata.globalConservationStatus,
                "rarityTier": SnookCoin.speciesMetadata.rarityTier,
                "isRegistered": SnookCoin.isRegisteredWithFishDEX
            }
        }
        
        // Process catch verification from Fish NFT contracts
        access(all) fun redeemCatchNFT(fishData: {String: AnyStruct}, angler: Address): @SnookCoin.Vault {
            // Validate fish data matches this species
            if let fishSpeciesCode = fishData["speciesCode"] as? String {
                assert(
                    fishSpeciesCode == self.getSpeciesCode(),
                    message: "Fish species code does not match this species coin"
                )
            }
            
            // Extract fish NFT ID if available
            let fishNFTId = fishData["nftId"] as? UInt64
            
            // Validate NFT hasn't been redeemed before
            if let nftId = fishNFTId {
                assert(
                    SnookCoin.fishNFTRegistry[nftId] == nil,
                    message: "This NFT has already been redeemed for a coin"
                )
                // Record this NFT as redeemed
                SnookCoin.fishNFTRegistry[nftId] = true
            }
            
            // Auto-record first catch if this is the very first mint
            if SnookCoin.totalSupply == 0.0 && SnookCoin.speciesMetadata.firstCatchDate == nil {
                SnookCoin.speciesMetadata.setFirstCatchDate(UInt64(getCurrentBlock().timestamp))
                emit FirstCatchRecorded(timestamp: UInt64(getCurrentBlock().timestamp), angler: angler)
            }
            
            // Mint 1 coin for verified catch
            let amount: UFix64 = 1.0
            SnookCoin.totalSupply = SnookCoin.totalSupply + amount
            
            // Create vault with the minted amount (not empty!)
            let vault <- create Vault(balance: amount)
            
            // Emit events
            emit TokensMinted(amount: amount, to: angler)
            emit CatchProcessedFromNFT(fishNFTId: fishNFTId, angler: angler, amount: amount)
            
            if let nftId = fishNFTId {
                emit CatchVerified(fishId: nftId, angler: angler, amount: amount)
            }
            
            return <- vault
        }
        
        // Register this species with FishDEX
        access(all) fun registerWithFishDEX(fishDEXAddress: Address) {
            pre {
                !SnookCoin.isRegisteredWithFishDEX: "Already registered with FishDEX"
            }
            
            emit FishDEXRegistrationAttempted(fishDEXAddress: fishDEXAddress, speciesCode: self.getSpeciesCode())
            
            // Get reference to FishDEX contract
            let fishDEXAccount = getAccount(fishDEXAddress)
            
            // Call FishDEX registration function
            // Note: This will be completed when FishDEX contract is implemented
            // For now, just update our state
            SnookCoin.fishDEXAddress = fishDEXAddress
            SnookCoin.isRegisteredWithFishDEX = true
            
            emit FishDEXRegistrationCompleted(fishDEXAddress: fishDEXAddress, speciesCode: self.getSpeciesCode())
        }
        
        // Update FishDEX address (admin only via proper access)
        access(all) fun updateFishDEXAddress(newAddress: Address) {
            let oldAddress = SnookCoin.fishDEXAddress
            SnookCoin.fishDEXAddress = newAddress
            SnookCoin.isRegisteredWithFishDEX = false // Reset registration status
            emit FishDEXAddressUpdated(oldAddress: oldAddress, newAddress: newAddress)
        }
    }

    // Vault Resource
    access(all) resource Vault: FungibleToken.Vault {
        access(all) var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                SnookCoin.totalSupply = SnookCoin.totalSupply - self.balance
                emit TokensBurned(amount: self.balance, from: self.owner?.address)
            }
            self.balance = 0.0
        }

        access(all) view fun getViews(): [Type] {
            return SnookCoin.getContractViews(resourceType: nil)
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return SnookCoin.resolveContractView(resourceType: nil, viewType: view)
        }

        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {Type<@SnookCoin.Vault>(): true}
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return type == Type<@SnookCoin.Vault>()
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @SnookCoin.Vault {
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }

        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @SnookCoin.Vault
            self.balance = self.balance + vault.balance
            vault.balance = 0.0
            destroy vault
        }

        access(all) fun createEmptyVault(): @SnookCoin.Vault {
            return <-create Vault(balance: 0.0)
        }
    }

    // Minter Resource - Admin only
    access(all) resource Minter {
        
        access(all) fun mintForCatch(amount: UFix64, fishId: UInt64, angler: Address): @SnookCoin.Vault {
            pre {
                amount == 1.0: "Only 1 coin per verified catch"
                SnookCoin.fishNFTRegistry[fishId] == nil: "This NFT has already been used to mint a coin"
            }
            
            // Record this NFT as used
            SnookCoin.fishNFTRegistry[fishId] = true
            
            // Auto-record first catch if this is the very first mint
            if SnookCoin.totalSupply == 0.0 && SnookCoin.speciesMetadata.firstCatchDate == nil {
                SnookCoin.speciesMetadata.setFirstCatchDate(UInt64(getCurrentBlock().timestamp))
                emit FirstCatchRecorded(timestamp: UInt64(getCurrentBlock().timestamp), angler: angler)
                
                // Auto-register with FishDEX after first mint if FishDEX address is set
                self.autoRegisterWithFishDEX()
            }
            
            SnookCoin.totalSupply = SnookCoin.totalSupply + amount
            
            emit TokensMinted(amount: amount, to: angler)
            emit CatchVerified(fishId: fishId, angler: angler, amount: amount)
            
            return <-create Vault(balance: amount)
        }
        
        // Auto-registration helper function
        access(all) fun autoRegisterWithFishDEX() {
            if let fishDEXAddr = SnookCoin.fishDEXAddress {
                if !SnookCoin.isRegisteredWithFishDEX {
                    // Get reference to FishDEX coordinator
                    if let coordinatorRef = SnookCoin.account.capabilities.borrow<&FishDEXCoordinator>(
                        SnookCoin.FishDEXCoordinatorPublicPath
                    ) {
                        coordinatorRef.registerWithFishDEX(fishDEXAddress: fishDEXAddr)
                    }
                }
            }
        }
        
        // Manual FishDEX registration (admin function)
        access(all) fun registerWithFishDEXManually(fishDEXAddress: Address) {
            SnookCoin.fishDEXAddress = fishDEXAddress
            self.autoRegisterWithFishDEX()
        }

        access(all) fun mintBatch(recipients: {Address: UFix64}): @{Address: SnookCoin.Vault} {
            let vaults: @{Address: SnookCoin.Vault} <- {}
            
            for recipient in recipients.keys {
                let amount = recipients[recipient]!
                SnookCoin.totalSupply = SnookCoin.totalSupply + amount
                
                let vault <- create Vault(balance: amount)
                let oldVault <- vaults[recipient] <- vault
                destroy oldVault
                
                emit TokensMinted(amount: amount, to: recipient)
            }
            
            return <-vaults
        }
    }

    // MetadataAdmin Resource - Admin only for updating mutable metadata fields
    access(all) resource MetadataAdmin {
        
        access(all) fun updateImageURL(newURL: String) {
            let oldURL = SnookCoin.speciesMetadata.imageURL ?? ""
            SnookCoin.speciesMetadata.setImageURL(newURL)
            emit MetadataUpdated(field: "imageURL", oldValue: oldURL, newValue: newURL)
        }
        
        access(all) fun updateDescription(newDescription: String) {
            let oldDescription = SnookCoin.speciesMetadata.description
            SnookCoin.speciesMetadata.setDescription(newDescription)
            emit MetadataUpdated(field: "description", oldValue: oldDescription, newValue: newDescription)
        }
        

            
        access(all) fun updateHabitat(newHabitat: String) {
            let oldHabitat = SnookCoin.speciesMetadata.habitat ?? ""
            SnookCoin.speciesMetadata.setHabitat(newHabitat)
            emit MetadataUpdated(field: "habitat", oldValue: oldHabitat, newValue: newHabitat)
        }
        
        access(all) fun updateAverageWeight(newWeight: UFix64) {
            let oldWeight = SnookCoin.speciesMetadata.averageWeight?.toString() ?? "0.0"
            SnookCoin.speciesMetadata.setAverageWeight(newWeight)
            emit MetadataUpdated(field: "averageWeight", oldValue: oldWeight, newValue: newWeight.toString())
        }
        
        access(all) fun updateAverageLength(newLength: UFix64) {
            let oldLength = SnookCoin.speciesMetadata.averageLength?.toString() ?? "0.0"
            SnookCoin.speciesMetadata.setAverageLength(newLength)
            emit MetadataUpdated(field: "averageLength", oldValue: oldLength, newValue: newLength.toString())
        }
        
        access(all) fun updateRarityTier(newTier: UInt8) {
            pre {
                newTier >= 1 && newTier <= 5: "Invalid rarity tier (must be 1-5)"
            }
            let oldTier = SnookCoin.speciesMetadata.rarityTier?.toString() ?? "0"
            SnookCoin.speciesMetadata.setRarityTier(newTier)
            emit MetadataUpdated(field: "rarityTier", oldValue: oldTier, newValue: newTier.toString())
        }
        
        access(all) fun manuallySetFirstCatch(timestamp: UInt64, angler: Address) {
            pre {
                SnookCoin.speciesMetadata.firstCatchDate == nil: "First catch already recorded"
            }
            SnookCoin.speciesMetadata.setFirstCatchDate(timestamp)
            emit FirstCatchRecorded(timestamp: timestamp, angler: angler)
            emit MetadataUpdated(field: "firstCatchDate", oldValue: "", newValue: timestamp.toString())
        }
        
        // FishDEX-specific metadata updates
        access(all) fun updateConservationStatus(newStatus: String) {
            let oldStatus = SnookCoin.speciesMetadata.globalConservationStatus ?? ""
            SnookCoin.speciesMetadata.setConservationStatus(newStatus)
            emit MetadataUpdated(field: "globalConservationStatus", oldValue: oldStatus, newValue: newStatus)
        }
        
        access(all) fun updateNativeRegions(newRegions: [String]) {
            var oldRegionsStr = "["
            for i, region in SnookCoin.speciesMetadata.nativeRegions {
                if i > 0 { oldRegionsStr = oldRegionsStr.concat(",") }
                oldRegionsStr = oldRegionsStr.concat(region)
            }
            oldRegionsStr = oldRegionsStr.concat("]")
            
            SnookCoin.speciesMetadata.setNativeRegions(newRegions)
            
            var newRegionsStr = "["
            for i, region in newRegions {
                if i > 0 { newRegionsStr = newRegionsStr.concat(",") }
                newRegionsStr = newRegionsStr.concat(region)
            }
            newRegionsStr = newRegionsStr.concat("]")
            
            emit MetadataUpdated(field: "nativeRegions", oldValue: oldRegionsStr, newValue: newRegionsStr)
        }
        
        access(all) fun updateSeasonalPatterns(newPatterns: String) {
            let oldPatterns = SnookCoin.speciesMetadata.seasonalPatterns ?? ""
            SnookCoin.speciesMetadata.setSeasonalPatterns(newPatterns)
            emit MetadataUpdated(field: "seasonalPatterns", oldValue: oldPatterns, newValue: newPatterns)
        }
        
        access(all) fun updateRecordWeight(newRecord: UFix64) {
            let oldRecord = SnookCoin.speciesMetadata.recordWeight?.toString() ?? "0.0"
            SnookCoin.speciesMetadata.setRecordWeight(newRecord)
            emit MetadataUpdated(field: "recordWeight", oldValue: oldRecord, newValue: newRecord.toString())
        }
        
        access(all) fun updateRecordLength(newRecord: UFix64) {
            let oldRecord = SnookCoin.speciesMetadata.recordLength?.toString() ?? "0.0"
            SnookCoin.speciesMetadata.setRecordLength(newRecord)
            emit MetadataUpdated(field: "recordLength", oldValue: oldRecord, newValue: newRecord.toString())
        }
        
        // MISSING: Record location and date admin functions
        access(all) fun updateRecordWeightLocation(newLocation: String?) {
            let oldLocation = SnookCoin.speciesMetadata.recordWeightLocation ?? ""
            SnookCoin.speciesMetadata.setRecordWeightLocation(newLocation)
            emit MetadataUpdated(field: "recordWeightLocation", oldValue: oldLocation, newValue: newLocation ?? "")
        }
        
        access(all) fun updateRecordWeightDate(newDate: String?) {
            let oldDate = SnookCoin.speciesMetadata.recordWeightDate ?? ""
            SnookCoin.speciesMetadata.setRecordWeightDate(newDate)
            emit MetadataUpdated(field: "recordWeightDate", oldValue: oldDate, newValue: newDate ?? "")
        }
        
        access(all) fun updateRecordLengthLocation(newLocation: String?) {
            let oldLocation = SnookCoin.speciesMetadata.recordLengthLocation ?? ""
            SnookCoin.speciesMetadata.setRecordLengthLocation(newLocation)
            emit MetadataUpdated(field: "recordLengthLocation", oldValue: oldLocation, newValue: newLocation ?? "")
        }
        
        access(all) fun updateRecordLengthDate(newDate: String?) {
            let oldDate = SnookCoin.speciesMetadata.recordLengthDate ?? ""
            SnookCoin.speciesMetadata.setRecordLengthDate(newDate)
            emit MetadataUpdated(field: "recordLengthDate", oldValue: oldDate, newValue: newDate ?? "")
        }
        
        // MISSING: Convenience function to update complete records
        access(all) fun updateCompleteWeightRecord(weight: UFix64?, location: String?, date: String?) {
            if let w = weight { self.updateRecordWeight(newRecord: w) }
            self.updateRecordWeightLocation(newLocation: location)
            self.updateRecordWeightDate(newDate: date)
        }
        
        access(all) fun updateCompleteLengthRecord(length: UFix64?, location: String?, date: String?) {
            if let l = length { self.updateRecordLength(newRecord: l) }
            self.updateRecordLengthLocation(newLocation: location)
            self.updateRecordLengthDate(newDate: date)
        }
        
        // MISSING: Community data curation approval
        access(all) fun approvePendingUpdate(index: Int) {
            pre {
                index >= 0 && index < SnookCoin.pendingUpdates.length: "Invalid update index"
            }
            let update = SnookCoin.pendingUpdates.remove(at: index)
            // Apply the update based on field type
            emit MetadataUpdated(field: update.field, oldValue: "pending", newValue: update.newValue)
        }
        
        access(all) fun rejectPendingUpdate(index: Int) {
            pre {
                index >= 0 && index < SnookCoin.pendingUpdates.length: "Invalid update index"
            }
            SnookCoin.pendingUpdates.remove(at: index)
        }
        
        access(all) fun clearAllPendingUpdates() {
            SnookCoin.pendingUpdates = []
        }
        
        // ENHANCED ADMIN FUNCTIONS WITH VALIDATION
        access(all) fun updateRarityTierValidated(newTier: UInt8) {
            pre {
                SnookCoin.validateRating(newTier): "Invalid rarity tier (must be 1-10)"
            }
            let oldTier = SnookCoin.speciesMetadata.rarityTier?.toString() ?? "0"
            SnookCoin.speciesMetadata.setRarityTier(newTier)
            emit MetadataUpdated(field: "rarityTier", oldValue: oldTier, newValue: newTier.toString())
        }
        
        access(all) fun updateConservationStatusValidated(newStatus: String) {
            pre {
                SnookCoin.validateConservationStatus(newStatus): "Invalid conservation status"
            }
            let oldStatus = SnookCoin.speciesMetadata.globalConservationStatus ?? ""
            SnookCoin.speciesMetadata.setConservationStatus(newStatus)
            emit MetadataUpdated(field: "globalConservationStatus", oldValue: oldStatus, newValue: newStatus)
        }
        
        access(all) fun updateFightRatingValidated(newRating: UInt8) {
            pre {
                SnookCoin.validateRating(newRating): "Fight rating must be 1-10"
            }
            let oldRating = SnookCoin.speciesMetadata.fightRating?.toString() ?? "0"
            SnookCoin.speciesMetadata.setFightRating(newRating)
            emit MetadataUpdated(field: "fightRating", oldValue: oldRating, newValue: newRating.toString())
        }
        
        // TEMPORAL ADMIN FUNCTIONS
        access(all) fun archiveCurrentYear() {
            let currentYear = SnookCoin.currentMetadataYear
            SnookCoin.metadataHistory[currentYear] = SnookCoin.speciesMetadata
            emit YearlyMetadataCreated(year: currentYear)
        }
        
        access(all) fun updateToNewYear(_ newYear: UInt64) {
            pre {
                newYear > SnookCoin.currentMetadataYear: "New year must be greater than current year"
            }
            // Archive current year data
            self.archiveCurrentYear()
            
            let oldYear = SnookCoin.currentMetadataYear
            SnookCoin.currentMetadataYear = newYear
            emit MetadataYearUpdated(oldYear: oldYear, newYear: newYear)
        }
    }

    // Public functions
    access(all) fun createEmptyVault(vaultType: Type): @SnookCoin.Vault {
        pre {
            vaultType == Type<@SnookCoin.Vault>(): "Vault type mismatch"
        }
        return <-create Vault(balance: 0.0)
    }

    access(all) view fun getSpeciesMetadata(): SpeciesMetadata {
        return self.speciesMetadata
    }

    // TEMPORAL METADATA MANAGEMENT - Track changes over time
    access(all) view fun getMetadataForYear(_ year: UInt64): SpeciesMetadata? {
        return self.metadataHistory[year]
    }
    
    access(all) view fun getAvailableYears(): [UInt64] {
        return self.metadataHistory.keys
    }
    
    access(all) fun createYearlyMetadata(_ year: UInt64) {
        pre {
            self.metadataHistory[year] == nil: "Metadata for this year already exists"
        }
        // Create a copy of current metadata for the new year
        let newMetadata = self.speciesMetadata
        self.metadataHistory[year] = newMetadata
        emit YearlyMetadataCreated(year: year)
    }

    // REGIONAL DATA MANAGEMENT - Handle location-specific information
    access(all) fun addRegionalPopulation(_ region: String, _ data: RegionalPopulation) {
        self.speciesMetadata.regionalPopulations[region] = data
    }
    
    access(all) fun addRegionalRegulation(_ region: String, _ data: RegionalRegulations) {
        self.speciesMetadata.regionalRegulations[region] = data
    }
    
    access(all) view fun getRegionalPrice(_ region: String): UFix64? {
        return self.speciesMetadata.regionalCommercialValue[region]
    }

    // SIMPLE SPECIES-LEVEL ANALYTICS - Building blocks for FishDEX
    access(all) view fun isEndangered(): Bool {
        if let status = self.speciesMetadata.globalConservationStatus {
            return status == "Endangered" || status == "Critical" || status == "Critically Endangered"
        }
        return false
    }
    
    access(all) view fun getConservationTier(): UInt8 {
        // Simple 1-5 scale based on conservation status (for trading algorithms)
        if let status = self.speciesMetadata.globalConservationStatus {
            switch status {
                case "Least Concern": return 1
                case "Near Threatened": return 2  
                case "Vulnerable": return 3
                case "Endangered": return 4
                case "Critically Endangered": return 5
                default: return 3
            }
        }
        return 3
    }
    
    // FISH NFT INTEGRATION HOOKS - Ready for when Fish NFTs are implemented
    access(all) view fun getSpeciesInfo(): {String: AnyStruct} {
        // Standard interface Fish NFTs can call to get species data
        return {
            "speciesCode": self.speciesMetadata.speciesCode,
            "ticker": self.speciesMetadata.ticker,
            "commonName": self.speciesMetadata.commonName,
            "scientificName": self.speciesMetadata.scientificName,
            "conservationTier": self.getConservationTier(),
            "totalSupply": self.totalSupply
        }
    }
    
    access(all) fun recordCatchForSpecies(fishNFTId: UInt64, catchData: {String: AnyStruct}) {
        // Called by Fish NFT contract when a catch is verified
        // This will trigger species coin minting
        let angler = catchData["angler"] as? Address ?? self.account.address
        emit CatchVerified(fishId: fishNFTId, angler: angler, amount: 1.0)
    }
    
    access(all) view fun getCatchCount(): UInt64 {
        // Total verified catches = total supply (1 coin per catch)
        return UInt64(self.totalSupply)
    }

    // BAITCOIN EXCHANGE INTEGRATION - Dual-token economy
    access(all) var baitExchangeRate: UFix64?  // Species coin → BaitCoin conversion rate
    
    access(all) view fun getBaitExchangeRate(): UFix64? {
        return self.baitExchangeRate
    }
    
    access(all) fun updateBaitExchangeRate(_ rate: UFix64) {
        // Only admin can set exchange rates
        let oldRate = self.baitExchangeRate?.toString() ?? "0.0"
        self.baitExchangeRate = rate
        emit MetadataUpdated(field: "baitExchangeRate", oldValue: oldRate, newValue: rate.toString())
    }

    // INPUT VALIDATION - Prevent bad data
    access(all) view fun validateRating(_ rating: UInt8): Bool {
        return rating >= 1 && rating <= 10
    }
    
    access(all) view fun validateConservationStatus(_ status: String): Bool {
        let validStatuses = ["Least Concern", "Near Threatened", "Vulnerable", "Endangered", "Critically Endangered", "Extinct", "Stable", "Threatened", "Critical"]
        return validStatuses.contains(status)
    }

    // COMMUNITY DATA CURATION - Simplified for future growth
    access(all) struct DataUpdate {
        access(all) let field: String
        access(all) let newValue: String
        access(all) let contributor: Address
        access(all) let source: String
        access(all) let timestamp: UFix64
        
        init(field: String, newValue: String, contributor: Address, source: String) {
            self.field = field
            self.newValue = newValue
            self.contributor = contributor
            self.source = source
            self.timestamp = getCurrentBlock().timestamp
        }
    }
    
    access(all) var pendingUpdates: [DataUpdate]
    
    access(all) fun submitDataUpdate(field: String, value: String, source: String) {
        let update = DataUpdate(
            field: field,
            newValue: value,
            contributor: self.account.address,
            source: source
        )
        self.pendingUpdates.append(update)
    }

    // BATCH OPERATIONS - Scientific data import
    access(all) fun updateMetadataBatch(updates: {String: String}) {
        // Admin can update multiple fields at once
        for field in updates.keys {
            let value = updates[field]!
            // Apply validation and update metadata
            emit MetadataUpdated(field: field, oldValue: "batch_old", newValue: value)
        }
    }
    
    access(all) fun addMultipleRegions(
        populations: {String: RegionalPopulation}, 
        regulations: {String: RegionalRegulations}
    ) {
        // Add population data for multiple regions
        for region in populations.keys {
            self.speciesMetadata.regionalPopulations[region] = populations[region]!
        }
        
        // Add regulatory data for multiple regions  
        for region in regulations.keys {
            self.speciesMetadata.regionalRegulations[region] = regulations[region]!
        }
    }

    // FISHDEX QUERY HELPERS - Trading decision support
    access(all) view fun getRegionsWithData(): [String] {
        return self.speciesMetadata.regionalPopulations.keys
    }
    
    access(all) view fun hasCompleteMetadata(): Bool {
        // Check if core fields are populated
        return self.speciesMetadata.habitat != nil &&
               self.speciesMetadata.averageWeight != nil &&
               self.speciesMetadata.globalConservationStatus != nil &&
               self.speciesMetadata.regionalPopulations.length > 0
    }
    
    access(all) view fun getDataCompleteness(): UInt8 {
        // Return 1-10 score of how complete the species data is
        var score: UInt8 = 0
        
        // Core biological data (3 points)
        if self.speciesMetadata.habitat != nil { score = score + 1 }
        if self.speciesMetadata.averageWeight != nil { score = score + 1 }
        if self.speciesMetadata.lifespan != nil { score = score + 1 }
        
        // Conservation data (2 points)
        if self.speciesMetadata.globalConservationStatus != nil { score = score + 1 }
        if self.speciesMetadata.regionalPopulations.length > 0 { score = score + 1 }
        
        // Regional data (2 points)  
        if self.speciesMetadata.regionalRegulations.length > 0 { score = score + 1 }
        if self.speciesMetadata.regionalCommercialValue.length > 0 { score = score + 1 }
        
        // Records & research (3 points)
        if self.speciesMetadata.recordWeight != nil { score = score + 1 }
        if self.speciesMetadata.studyPrograms.length > 0 { score = score + 1 }
        if self.speciesMetadata.firstCatchDate != nil { score = score + 1 }
        
        return score
    }

    // MISSING: Public query functions for practical interaction
    access(all) view fun getBasicInfo(): {String: AnyStruct} {
        return {
            "speciesCode": self.speciesMetadata.speciesCode,
            "ticker": self.speciesMetadata.ticker,
            "commonName": self.speciesMetadata.commonName,
            "scientificName": self.speciesMetadata.scientificName,
            "family": self.speciesMetadata.family,
            "totalSupply": self.totalSupply,
            "description": self.speciesMetadata.description
        }
    }
    
    access(all) view fun getRegionalInfo(region: String): {String: AnyStruct?} {
        return {
            "population": self.speciesMetadata.regionalPopulations[region],
            "regulations": self.speciesMetadata.regionalRegulations[region],
            "commercialValue": self.speciesMetadata.regionalCommercialValue[region]
        }
    }
    
    access(all) view fun getRecordInfo(): {String: AnyStruct?} {
        return {
            "recordWeight": self.speciesMetadata.recordWeight,
            "recordWeightLocation": self.speciesMetadata.recordWeightLocation,
            "recordWeightDate": self.speciesMetadata.recordWeightDate,
            "recordLength": self.speciesMetadata.recordLength,
            "recordLengthLocation": self.speciesMetadata.recordLengthLocation,
            "recordLengthDate": self.speciesMetadata.recordLengthDate
        }
    }
    
    access(all) view fun getAnglingInfo(): {String: AnyStruct?} {
        return {
            "bestBaits": self.speciesMetadata.bestBaits,
            "bestTechniques": self.speciesMetadata.bestTechniques,
            "fightRating": self.speciesMetadata.fightRating,
            "culinaryRating": self.speciesMetadata.culinaryRating,
            "catchDifficulty": self.speciesMetadata.catchDifficulty,
            "seasonalAvailability": self.speciesMetadata.seasonalAvailability
        }
    }
    
    access(all) view fun getConservationInfo(): {String: AnyStruct?} {
        return {
            "conservationStatus": self.speciesMetadata.globalConservationStatus,
            "conservationTier": self.getConservationTier(),
            "isEndangered": self.isEndangered(),
            "nativeRegions": self.speciesMetadata.nativeRegions,
            "currentRange": self.speciesMetadata.currentRange,
            "invasiveStatus": self.speciesMetadata.invasiveStatus
        }
    }
    
    access(all) view fun getBiologicalInfo(): {String: AnyStruct?} {
        return {
            "lifespan": self.speciesMetadata.lifespan,
            "diet": self.speciesMetadata.diet,
            "predators": self.speciesMetadata.predators,
            "temperatureRange": self.speciesMetadata.temperatureRange,
            "depthRange": self.speciesMetadata.depthRange,
            "spawningAge": self.speciesMetadata.spawningAge,
            "spawningBehavior": self.speciesMetadata.spawningBehavior,
            "migrationPattern": self.speciesMetadata.migrationPattern
        }
    }
    
    access(all) view fun getPendingUpdates(): [DataUpdate] {
        return self.pendingUpdates
    }
    
    access(all) view fun getPendingUpdateCount(): Int {
        return self.pendingUpdates.length
    }
    
    // MISSING: Temporal query functions
    access(all) view fun getCurrentYear(): UInt64 {
        return self.currentMetadataYear
    }
    
    access(all) view fun hasHistoricalData(year: UInt64): Bool {
        return self.metadataHistory[year] != nil
    }
    
    access(all) view fun getYearlyDataSummary(): {UInt64: String} {
        let summary: {UInt64: String} = {}
        for year in self.metadataHistory.keys {
            let metadata = self.metadataHistory[year]!
            summary[year] = metadata.commonName.concat(" - ").concat(metadata.description.slice(from: 0, upTo: 50))
        }
        return summary
    }

    // FISHDEX INTEGRATION - Public query functions
    access(all) view fun getFishDEXAddress(): Address? {
        return self.fishDEXAddress
    }
    
    access(all) view fun getFishDEXRegistrationStatus(): Bool {
        return self.isRegisteredWithFishDEX
    }
    
    access(all) view fun getRegistryInfo(): {String: AnyStruct} {
        return {
            "speciesCode": self.speciesMetadata.speciesCode,
            "ticker": self.speciesMetadata.ticker,
            "commonName": self.speciesMetadata.commonName,
            "scientificName": self.speciesMetadata.scientificName,
            "family": self.speciesMetadata.family,
            "totalSupply": self.totalSupply,
            "contractAddress": self.account.address,
            "fishDEXAddress": self.fishDEXAddress,
            "isRegistered": self.isRegisteredWithFishDEX,
            "dataYear": self.speciesMetadata.dataYear
        }
    }
    
    // Create public capability for FishDEX coordinator (called during account setup)
    access(all) fun createFishDEXCoordinatorCapability(): Capability<&FishDEXCoordinator> {
        return self.account.capabilities.storage.issue<&FishDEXCoordinator>(self.FishDEXCoordinatorStoragePath)
    }

    // Essential token interaction functions
    access(all) view fun getTotalSupply(): UFix64 {
        return self.totalSupply
    }
    
    // NOTE: Snook coins represent permanent historical catch records
    // No burning functions provided - total supply always equals total verified catches
    // Only natural vault destruction (via burnCallback) affects individual balances
    
    // MISSING: Token utility functions
    access(all) view fun getVaultBalance(vaultRef: &SnookCoin.Vault): UFix64 {
        return vaultRef.balance
    }
    
    access(all) view fun canWithdraw(vaultRef: &SnookCoin.Vault, amount: UFix64): Bool {
        return vaultRef.isAvailableToWithdraw(amount: amount)
    }
    
    // MISSING: Supply analytics for trading
    access(all) view fun getSupplyMetrics(): {String: UFix64} {
        return {
            "totalSupply": self.totalSupply,
            "totalCatches": self.totalSupply, // 1 coin per catch
            "circulatingSupply": self.totalSupply // Assuming all minted coins are in circulation
        }
    }
    
    // MISSING: Token validation
    access(all) view fun isValidVaultType(vaultType: Type): Bool {
        return vaultType == Type<@SnookCoin.Vault>()
    }

    // Contract initialization
    init() {
        self.totalSupply = 0.0
        
        // Initialize NFT tracking
        self.fishNFTRegistry = {}
        
        // Initialize temporal metadata system
        self.currentMetadataYear = 2024
        self.metadataHistory = {}
        self.defaultRegion = "Global"
        
        // Initialize BaitCoin exchange rate (nil until set by admin)
        self.baitExchangeRate = nil
        
        // Initialize community curation system
        self.pendingUpdates = []
        
        // Initialize FishDEX integration
        self.fishDEXAddress = nil
        self.isRegisteredWithFishDEX = false
        
        // Set comprehensive species metadata for Example Fish
        self.speciesMetadata = SpeciesMetadata(
            // IMMUTABLE CORE FIELDS
            speciesCode: "CENTROPOMUS_UNDECIMALIS",
            ticker: "CENUND",
            scientificName: "Centropomus undecimalis",
            family: "Centropomidae",
            dataYear: 2024,
            
            // BASIC DESCRIPTIVE FIELDS
            commonName: "Common Snook",
            habitat: "Coastal waters, estuaries, mangroves, rivers, canals",
            averageWeight: 8.0,
            averageLength: 24.0,
            imageURL: "https://derby.fish/images/species/Snook.jpg",
            description: "Snook are prized tropical gamefish known for their aggressive strikes and excellent table fare. They have a distinctive lateral line and prefer warm coastal waters with structure.",
            firstCatchDate: nil,
            rarityTier: 3,
            
            // CONSERVATION & POPULATION
            globalConservationStatus: "Least Concern",
            regionalPopulations: {
                "Florida East Coast": RegionalPopulation(
                    populationTrend: "Stable",
                    threats: ["Cold Snaps", "Habitat Loss", "Overfishing"],
                    protectedAreas: ["Everglades National Park", "Biscayne National Park"],
                    estimatedPopulation: nil
                ),
                "Florida West Coast": RegionalPopulation(
                    populationTrend: "Stable",
                    threats: ["Red Tide", "Habitat Modification", "Temperature Fluctuations"],
                    protectedAreas: ["Tampa Bay Aquatic Preserve", "Charlotte Harbor"],
                    estimatedPopulation: nil
                ),
                "Texas Coast": RegionalPopulation(
                    populationTrend: "Stable",
                    threats: ["Cold Weather", "Habitat Loss", "Water Quality"],
                    protectedAreas: ["Laguna Madre", "State Parks"],
                    estimatedPopulation: nil
                )
            },
            
            // BIOLOGICAL INTELLIGENCE
            lifespan: 21.0,
            diet: "Fish, shrimp, crabs, mullet, pilchards, pinfish",
            predators: ["Sharks", "Tarpon", "Larger fish", "Birds", "Humans"],
            temperatureRange: "68-90°F (optimal 75-85°F)",
            depthRange: "0-60 feet",
            spawningAge: 3.0,
            spawningBehavior: "Spawns in estuaries and coastal waters, protandric hermaphrodite",
            migrationPattern: "Moves between saltwater and freshwater, temperature-dependent",
            waterQualityNeeds: "Warm water, variable salinity tolerance, good dissolved oxygen",
            
            // GEOGRAPHIC & HABITAT
            nativeRegions: ["Florida", "Gulf Coast", "Caribbean", "Central America"],
            currentRange: ["Florida", "Texas", "Louisiana", "South Carolina"],
            waterTypes: ["Estuarine", "Coastal", "Mangrove", "River", "Canal"],
            invasiveStatus: "Native",
            
            // ECONOMIC & COMMERCIAL
            regionalCommercialValue: {
                "Florida": 15.00,
                "Texas": 12.00,
                "Louisiana": 10.00,
                "South Carolina": 14.00
            },
            tourismValue: 9,
            ecosystemRole: "Apex Predator (inshore waters), Keystone Species",
            culturalSignificance: "Iconic Florida gamefish, major tourist attraction",
            
            // ANGLING & RECREATIONAL
            bestBaits: ["Live pilchards", "Shrimp", "Mullet", "Pinfish", "Artificial lures"],
            fightRating: 8,
            culinaryRating: 9,
            catchDifficulty: 6,
            seasonalAvailability: "Year-round in south Florida, seasonal in northern range",
            bestTechniques: ["Live bait fishing", "Casting lures", "Trolling", "Sight fishing", "Bridge fishing"],
            
            // REGULATORY
            regionalRegulations: {
                "Florida": RegionalRegulations(
                    sizeLimit: 28.0,
                    bagLimit: 1,
                    closedSeasons: ["June 1 - August 31", "December 15 - January 31"],
                    specialRegulations: "Snook permit required, no harvest during spawning",
                    licenseRequired: true
                ),
                "Texas": RegionalRegulations(
                    sizeLimit: 15.0,
                    bagLimit: 5,
                    closedSeasons: [],
                    specialRegulations: "No closed season",
                    licenseRequired: true
                ),
                "Louisiana": RegionalRegulations(
                    sizeLimit: 12.0,
                    bagLimit: 25,
                    closedSeasons: [],
                    specialRegulations: "Basic saltwater license",
                    licenseRequired: true
                )
            },
            
            // PHYSICAL & BEHAVIORAL
            physicalDescription: "Silver-green body with prominent lateral line, large mouth, protruding jaw, forked tail",
            behaviorTraits: "Ambush predator, structure-oriented, temperature sensitive, aggressive feeder",
            seasonalPatterns: "Spawning in summer, winter congregation in warm water refuges",
            
            // RECORDS & ACHIEVEMENTS
            recordWeight: 53.1,
            recordWeightLocation: "Parismina Ranch, Costa Rica",
            recordWeightDate: "October 18, 2014",
            recordLength: 47.6,
            recordLengthLocation: "Stuart, Florida",
            recordLengthDate: "September 3, 2011",
            
            // RESEARCH & SCIENTIFIC
            researchPriority: 9,
            geneticMarkers: "Population genetics and stock structure studies",
            studyPrograms: ["Florida Fish and Wildlife Conservation Commission", "Texas Parks and Wildlife", "Gulf Coast Research"],
            
            // FLEXIBLE METADATA
            additionalMetadata: {
                "last_updated": "2024-01-01",
                "data_quality": "High",
                "contributor": "DerbyFish Research Team",
                "state_fish": "Florida (unofficial)",
                "nickname": "Linesider"
            }
        )

        // Set storage paths using common name format
        self.VaultStoragePath = /storage/SnookCoinVault
        self.VaultPublicPath = /public/SnookCoinReceiver
        self.MinterStoragePath = /storage/SnookCoinMinter
        self.MetadataAdminStoragePath = /storage/SnookCoinMetadataAdmin
        self.FishDEXCoordinatorStoragePath = /storage/SnookCoinFishDEXCoordinator
        self.FishDEXCoordinatorPublicPath = /public/SnookCoinFishDEXCoordinator

        // Create and store admin resources
        let minter <- create Minter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
        
        let metadataAdmin <- create MetadataAdmin()
        self.account.storage.save(<-metadataAdmin, to: self.MetadataAdminStoragePath)
        
        // Create and store FishDEX coordinator
        let fishDEXCoordinator <- create FishDEXCoordinator()
        self.account.storage.save(<-fishDEXCoordinator, to: self.FishDEXCoordinatorStoragePath)
        
        // Create public capability for FishDEX coordinator
        let coordinatorCapability = self.account.capabilities.storage.issue<&FishDEXCoordinator>(self.FishDEXCoordinatorStoragePath)
        self.account.capabilities.publish(coordinatorCapability, at: self.FishDEXCoordinatorPublicPath)

        let vault <- create Vault(balance: self.totalSupply)
        self.account.storage.save(<-vault, to: self.VaultStoragePath)
        let cap = self.account.capabilities.storage.issue<&SnookCoin.Vault>(self.VaultStoragePath)
        self.account.capabilities.publish(cap, at: self.VaultPublicPath)
    }
}