import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FishNFT"
import "RandomBeacon"
import "FlowToken"

access(all) contract FishCardNFT: NonFungibleToken {
    // --- Contract Storage Paths ---
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let ConfigManagerStoragePath: StoragePath

    // --- Contract State ---
    access(self) var totalSupply: UInt64
    access(self) var maxSupply: UInt64
    access(self) var mintPrice: UFix64
    access(self) var paused: Bool
    
    // --- Per FishNFT Configuration ---
    access(self) var fishNFTConfigs: {UInt64: FishNFTConfig}
    
    // --- Minting Configuration ---
    access(self) var mintingPhase: String  // "pre-sale", "public", "closed"
    access(self) var maxMintsPerAddress: UInt64  // Max mints per address
    access(self) var addressMintCounts: {Address: UInt64}  // Track mints per address
    access(self) var whitelistedAddresses: {Address: Bool}  // Pre-sale whitelist
    access(self) var preSalePrice: UFix64  // Special price for pre-sale
    access(self) var bulkMintDiscount: UFix64  // Discount for minting multiple at once
    access(self) var royaltyPercent: UFix64  // Royalty percentage for secondary sales
    access(self) var royaltyRecipient: Address  // Address to receive royalties
    access(self) var mintStartTime: UFix64  // When minting begins
    access(self) var mintEndTime: UFix64?  // Optional end time for minting
    access(self) var revealDelay: UFix64  // Time delay before reveals are allowed
    
    // --- Field Probability Configuration ---
    access(self) var fieldProbabilities: {String: UFix64}

    // --- Events ---
    access(all) event ContractInitialized()
    access(all) event Minted(id: UInt64, fishNFTID: UInt64)
    access(all) event Revealed(id: UInt64, revealedFields: [String])
    access(all) event ProbabilityUpdated(field: String, probability: UFix64)
    access(all) event CardRevealed(id: UInt64, field: String, revealed: Bool)
    access(all) event MintPriceUpdated(newPrice: UFix64)
    access(all) event MaxSupplyUpdated(newMaxSupply: UInt64)
    access(all) event ContractPaused(paused: Bool)
    access(all) event MintingPhaseChanged(phase: String)
    access(all) event AddressWhitelisted(address: Address)
    access(all) event AddressUnwhitelisted(address: Address)
    access(all) event PreSalePriceUpdated(newPrice: UFix64)
    access(all) event BulkDiscountUpdated(newDiscount: UFix64)
    access(all) event RoyaltyUpdated(percent: UFix64, recipient: Address)
    access(all) event MintTimesUpdated(startTime: UFix64, endTime: UFix64?)
    access(all) event RevealDelayUpdated(newDelay: UFix64)
    access(all) event ConfigurationUpdated(fishNFTID: UInt64)

    // --- FishNFT Configuration Structure ---
    access(all) struct FishNFTConfig {
        access(all) var isEnabled: Bool
        access(all) var maxSupply: UInt64
        access(all) var currentSupply: UInt64
        access(all) var mintPrice: UFix64
        access(all) var fieldProbabilities: {String: UFix64}
        access(all) var revealDelay: UFix64
        access(all) var addressMintCounts: {Address: UInt64}

        init(
            isEnabled: Bool,
            maxSupply: UInt64,
            mintPrice: UFix64
        ) {
            self.isEnabled = isEnabled
            self.maxSupply = maxSupply
            self.currentSupply = 0
            self.mintPrice = mintPrice
            self.revealDelay = 86400.0 // 24 hours
            self.addressMintCounts = {}
            
            // Initialize default probabilities
            self.fieldProbabilities = {
                "longitude": 0.3,
                "latitude": 0.3,
                "waterBody": 0.8,
                "waterDepth": 0.5,
                "structureType": 0.4,
                "bottomType": 0.4,
                "waterTemp": 0.6,
                "airTemp": 0.6,
                "weather": 0.7,
                "moonPhase": 0.5,
                "tide": 0.5,
                "barometricPressure": 0.4,
                "windSpeed": 0.6,
                "windDirection": 0.6,
                "skyConditions": 0.7,
                "location": 0.4,
                "waterClarity": 0.5,
                "currentStrength": 0.5,
                "gear": 0.3,
                "baitLure": 0.3,
                "technique": 0.4,
                "girth": 0.6,
                "fightDuration": 0.5,
                "rodType": 0.3,
                "reelType": 0.3,
                "lineType": 0.3,
                "leaderType": 0.3,
                "hookType": 0.3,
                "presentation": 0.4,
                "retrieveSpeed": 0.4,
                "catchDepth": 0.5
            }
        }
    }

    // --- Configuration Manager Resource ---
    access(all) resource ConfigManager {
        // Update configuration if authorized
        access(all) fun updateConfig(
            fishNFT: &FishNFT.NFT,
            config: FishNFTConfig,
            auth: Address
        ) {
            pre {
                auth == fishNFT.owner?.address || auth == FishCardNFT.account.address:
                    "Only FishNFT owner or DerbyFish can update configuration"
            }
            
            FishCardNFT.fishNFTConfigs[fishNFT.id] = config
            emit ConfigurationUpdated(fishNFTID: fishNFT.id)
        }

        // Initialize configuration for a FishNFT
        access(all) fun initializeConfig(
            fishNFT: &FishNFT.NFT,
            auth: Address
        ) {
            pre {
                auth == fishNFT.owner?.address || auth == FishCardNFT.account.address:
                    "Only FishNFT owner or DerbyFish can initialize configuration"
                FishCardNFT.fishNFTConfigs[fishNFT.id] == nil:
                    "Configuration already exists"
            }

            let config = FishNFTConfig(
                isEnabled: false,
                maxSupply: 100,
                mintPrice: 10.0
            )
            
            FishCardNFT.fishNFTConfigs[fishNFT.id] = config
            emit ConfigurationUpdated(fishNFTID: fishNFT.id)
        }
    }

    // --- Admin Resource ---
    access(all) resource Admin {
        // Update mint price
        access(all) fun setMintPrice(newPrice: UFix64) {
            pre {
                newPrice > 0.0: "Mint price must be greater than 0"
            }
            FishCardNFT.mintPrice = newPrice
            emit MintPriceUpdated(newPrice: newPrice)
        }

        // Update max supply
        access(all) fun setMaxSupply(newMaxSupply: UInt64) {
            pre {
                newMaxSupply >= FishCardNFT.totalSupply: "Cannot set max supply lower than current supply"
            }
            FishCardNFT.maxSupply = newMaxSupply
            emit MaxSupplyUpdated(newMaxSupply: newMaxSupply)
        }

        // Update field probabilities
        access(all) fun setFieldProbability(field: String, probability: UFix64) {
            pre {
                probability >= 0.0 && probability <= 1.0: "Probability must be between 0 and 1"
            }
            FishCardNFT.fieldProbabilities[field] = probability
            emit ProbabilityUpdated(field: field, probability: probability)
        }

        // Pause/unpause contract
        access(all) fun setPaused(paused: Bool) {
            FishCardNFT.paused = paused
            emit ContractPaused(paused: paused)
        }

        // Update minting phase
        access(all) fun setMintingPhase(phase: String) {
            pre {
                phase == "pre-sale" || phase == "public" || phase == "closed": "Invalid minting phase"
            }
            FishCardNFT.mintingPhase = phase
            emit MintingPhaseChanged(phase: phase)
        }

        // Whitelist management
        access(all) fun addToWhitelist(address: Address) {
            FishCardNFT.whitelistedAddresses[address] = true
            emit AddressWhitelisted(address: address)
        }

        access(all) fun removeFromWhitelist(address: Address) {
            FishCardNFT.whitelistedAddresses.remove(key: address)
            emit AddressUnwhitelisted(address: address)
        }

        // Update pre-sale price
        access(all) fun setPreSalePrice(newPrice: UFix64) {
            pre {
                newPrice > 0.0: "Pre-sale price must be greater than 0"
            }
            FishCardNFT.preSalePrice = newPrice
            emit PreSalePriceUpdated(newPrice: newPrice)
        }

        // Update bulk discount
        access(all) fun setBulkMintDiscount(newDiscount: UFix64) {
            pre {
                newDiscount >= 0.0 && newDiscount <= 1.0: "Discount must be between 0 and 1"
            }
            FishCardNFT.bulkMintDiscount = newDiscount
            emit BulkDiscountUpdated(newDiscount: newDiscount)
        }

        // Update royalty settings
        access(all) fun setRoyalty(percent: UFix64, recipient: Address) {
            pre {
                percent >= 0.0 && percent <= 0.25: "Royalty must be between 0% and 25%"
            }
            FishCardNFT.royaltyPercent = percent
            FishCardNFT.royaltyRecipient = recipient
            emit RoyaltyUpdated(percent: percent, recipient: recipient)
        }

        // Update minting times
        access(all) fun setMintTimes(startTime: UFix64, endTime: UFix64?) {
            pre {
                startTime > getCurrentBlock().timestamp: "Start time must be in the future"
                endTime == nil || endTime! > startTime: "End time must be after start time"
            }
            FishCardNFT.mintStartTime = startTime
            FishCardNFT.mintEndTime = endTime
            emit MintTimesUpdated(startTime: startTime, endTime: endTime)
        }

        // Update reveal delay
        access(all) fun setRevealDelay(newDelay: UFix64) {
            FishCardNFT.revealDelay = newDelay
            emit RevealDelayUpdated(newDelay: newDelay)
        }
    }

    // --- VRF Request Receipt ---
    access(all) resource Receipt {
        access(all) let betAmount: UFix64
        access(self) var request: @RandomBeacon.Request?

        init(betAmount: UFix64, request: @RandomBeacon.Request) {
            self.betAmount = betAmount
            self.request <- request
        }

        access(all) fun getRequestBlock(): UInt64? {
            return self.request?.blockHeight
        }

        access(all) fun popRequest(): @RandomBeacon.Request {
            pre {
                self.request != nil: "Request has already been used"
            }
            let request <- self.request <- nil
            return <-request!
        }

        destroy() {
            destroy self.request
        }
    }

    // --- Core Metadata Structure ---
    access(all) struct FishCardMetadata {
        // Original FishNFT reference and owner
        access(all) let fishNFTID: UInt64
        access(all) let owner: Address
        
        // CORE DATA - Always visible
        access(all) let species: String
        access(all) let scientific: String
        access(all) let length: UFix64
        access(all) let weight: UFix64?
        access(all) let timestamp: UFix64
        access(all) let speciesCode: String
        access(all) let hasRelease: Bool

        // LOCATION DATA - Each field has a reveal flag and protected value
        access(all) let isLongitudeRevealed: Bool
        access(self) let longitude: Fix64?
        
        access(all) let isLatitudeRevealed: Bool
        access(self) let latitude: Fix64?
        
        access(all) let isWaterBodyRevealed: Bool
        access(self) let waterBody: String?
        
        access(all) let isWaterDepthRevealed: Bool
        access(contract) let waterDepth: UFix64?
        
        access(all) let isStructureTypeRevealed: Bool
        access(contract) let structureType: String?
        
        access(all) let isBottomTypeRevealed: Bool
        access(contract) let bottomType: String?

        // ENVIRONMENTAL DATA
        access(all) let isWaterTempRevealed: Bool
        access(all) let isAirTempRevealed: Bool
        access(all) let isWeatherRevealed: Bool
        access(all) let isMoonPhaseRevealed: Bool
        access(all) let isTideRevealed: Bool
        access(all) let isBarometricPressureRevealed: Bool
        access(all) let isWindSpeedRevealed: Bool
        access(all) let isWindDirectionRevealed: Bool
        access(all) let isSkyConditionsRevealed: Bool

        access(contract) let waterTemp: UFix64?
        access(contract) let airTemp: UFix64?
        access(contract) let weather: String?
        access(contract) let moonPhase: String?
        access(contract) let tide: String?
        access(contract) let barometricPressure: UFix64?
        access(contract) let windSpeed: UFix64?
        access(contract) let windDirection: String?
        access(contract) let skyConditions: String?

        // ANGLER DATA
        access(all) let isLocationRevealed: Bool
        access(all) let isWaterClarityRevealed: Bool
        access(all) let isCurrentStrengthRevealed: Bool
        access(all) let isGearRevealed: Bool
        access(all) let isBaitLureRevealed: Bool
        access(all) let isTechniqueRevealed: Bool
        access(all) let isGirthRevealed: Bool
        access(all) let isFightDurationRevealed: Bool
        access(all) let isRodTypeRevealed: Bool
        access(all) let isReelTypeRevealed: Bool
        access(all) let isLineTypeRevealed: Bool
        access(all) let isLeaderTypeRevealed: Bool
        access(all) let isHookTypeRevealed: Bool
        access(all) let isPresentationRevealed: Bool
        access(all) let isRetrieveSpeedRevealed: Bool
        access(all) let isCatchDepthRevealed: Bool

        access(contract) let location: String?
        access(contract) let waterClarity: String?
        access(contract) let currentStrength: String?
        access(contract) let gear: String?
        access(contract) let baitLure: String?
        access(contract) let technique: String?
        access(contract) let girth: UFix64?
        access(contract) let fightDuration: UFix64?
        access(contract) let rodType: String?
        access(contract) let reelType: String?
        access(contract) let lineType: String?
        access(contract) let leaderType: String?
        access(contract) let hookType: String?
        access(contract) let presentation: String?
        access(contract) let retrieveSpeed: String?
        access(contract) let catchDepth: UFix64?

        // Function to get private data if caller is authorized
        access(all) fun getRevealedValue(_ field: String, caller: Address): AnyStruct? {
            pre {
                caller == self.owner: "Only the FishCard owner can access revealed values"
            }

            switch field {
                case "longitude":
                    return self.isLongitudeRevealed ? self.longitude : nil
                case "latitude":
                    return self.isLatitudeRevealed ? self.latitude : nil
                case "waterBody":
                    return self.isWaterBodyRevealed ? self.waterBody : nil
                case "waterDepth":
                    return self.isWaterDepthRevealed ? self.waterDepth : nil
                case "structureType":
                    return self.isStructureTypeRevealed ? self.structureType : nil
                case "bottomType":
                    return self.isBottomTypeRevealed ? self.bottomType : nil
                case "waterTemp":
                    return self.isWaterTempRevealed ? self.waterTemp : nil
                case "airTemp":
                    return self.isAirTempRevealed ? self.airTemp : nil
                case "weather":
                    return self.isWeatherRevealed ? self.weather : nil
                case "moonPhase":
                    return self.isMoonPhaseRevealed ? self.moonPhase : nil
                case "tide":
                    return self.isTideRevealed ? self.tide : nil
                case "barometricPressure":
                    return self.isBarometricPressureRevealed ? self.barometricPressure : nil
                case "windSpeed":
                    return self.isWindSpeedRevealed ? self.windSpeed : nil
                case "windDirection":
                    return self.isWindDirectionRevealed ? self.windDirection : nil
                case "skyConditions":
                    return self.isSkyConditionsRevealed ? self.skyConditions : nil
                case "location":
                    return self.isLocationRevealed ? self.location : nil
                case "waterClarity":
                    return self.isWaterClarityRevealed ? self.waterClarity : nil
                case "currentStrength":
                    return self.isCurrentStrengthRevealed ? self.currentStrength : nil
                case "gear":
                    return self.isGearRevealed ? self.gear : nil
                case "baitLure":
                    return self.isBaitLureRevealed ? self.baitLure : nil
                case "technique":
                    return self.isTechniqueRevealed ? self.technique : nil
                case "girth":
                    return self.isGirthRevealed ? self.girth : nil
                case "fightDuration":
                    return self.isFightDurationRevealed ? self.fightDuration : nil
                case "rodType":
                    return self.isRodTypeRevealed ? self.rodType : nil
                case "reelType":
                    return self.isReelTypeRevealed ? self.reelType : nil
                case "lineType":
                    return self.isLineTypeRevealed ? self.lineType : nil
                case "leaderType":
                    return self.isLeaderTypeRevealed ? self.leaderType : nil
                case "hookType":
                    return self.isHookTypeRevealed ? self.hookType : nil
                case "presentation":
                    return self.isPresentationRevealed ? self.presentation : nil
                case "retrieveSpeed":
                    return self.isRetrieveSpeedRevealed ? self.retrieveSpeed : nil
                case "catchDepth":
                    return self.isCatchDepthRevealed ? self.catchDepth : nil
                default:
                    return nil
            }
        }

        // Function to get all revealed values if authorized
        access(all) fun getAllRevealedValues(caller: Address): {String: AnyStruct}? {
            pre {
                caller == self.owner: "Only the FishCard owner can access revealed values"
            }

            let revealed: {String: AnyStruct} = {}
            
            if self.isLongitudeRevealed { revealed["longitude"] = self.longitude }
            if self.isLatitudeRevealed { revealed["latitude"] = self.latitude }
            if self.isWaterBodyRevealed { revealed["waterBody"] = self.waterBody }
            if self.isWaterDepthRevealed { revealed["waterDepth"] = self.waterDepth }
            if self.isStructureTypeRevealed { revealed["structureType"] = self.structureType }
            if self.isBottomTypeRevealed { revealed["bottomType"] = self.bottomType }
            if self.isWaterTempRevealed { revealed["waterTemp"] = self.waterTemp }
            if self.isAirTempRevealed { revealed["airTemp"] = self.airTemp }
            if self.isWeatherRevealed { revealed["weather"] = self.weather }
            if self.isMoonPhaseRevealed { revealed["moonPhase"] = self.moonPhase }
            if self.isTideRevealed { revealed["tide"] = self.tide }
            if self.isBarometricPressureRevealed { revealed["barometricPressure"] = self.barometricPressure }
            if self.isWindSpeedRevealed { revealed["windSpeed"] = self.windSpeed }
            if self.isWindDirectionRevealed { revealed["windDirection"] = self.windDirection }
            if self.isSkyConditionsRevealed { revealed["skyConditions"] = self.skyConditions }
            if self.isLocationRevealed { revealed["location"] = self.location }
            if self.isWaterClarityRevealed { revealed["waterClarity"] = self.waterClarity }
            if self.isCurrentStrengthRevealed { revealed["currentStrength"] = self.currentStrength }
            if self.isGearRevealed { revealed["gear"] = self.gear }
            if self.isBaitLureRevealed { revealed["baitLure"] = self.baitLure }
            if self.isTechniqueRevealed { revealed["technique"] = self.technique }
            if self.isGirthRevealed { revealed["girth"] = self.girth }
            if self.isFightDurationRevealed { revealed["fightDuration"] = self.fightDuration }
            if self.isRodTypeRevealed { revealed["rodType"] = self.rodType }
            if self.isReelTypeRevealed { revealed["reelType"] = self.reelType }
            if self.isLineTypeRevealed { revealed["lineType"] = self.lineType }
            if self.isLeaderTypeRevealed { revealed["leaderType"] = self.leaderType }
            if self.isHookTypeRevealed { revealed["hookType"] = self.hookType }
            if self.isPresentationRevealed { revealed["presentation"] = self.presentation }
            if self.isRetrieveSpeedRevealed { revealed["retrieveSpeed"] = self.retrieveSpeed }
            if self.isCatchDepthRevealed { revealed["catchDepth"] = self.catchDepth }

            return revealed
        }

        init(
            fishNFTID: UInt64,
            owner: Address,
            species: String,
            scientific: String,
            length: UFix64,
            weight: UFix64?,
            timestamp: UFix64,
            speciesCode: String,
            hasRelease: Bool,
            isLongitudeRevealed: Bool,
            longitude: Fix64?,
            isLatitudeRevealed: Bool,
            latitude: Fix64?,
            isWaterBodyRevealed: Bool,
            waterBody: String?,
            isWaterDepthRevealed: Bool,
            waterDepth: UFix64?,
            isStructureTypeRevealed: Bool,
            structureType: String?,
            isBottomTypeRevealed: Bool,
            bottomType: String?,
            isWaterTempRevealed: Bool,
            waterTemp: UFix64?,
            isAirTempRevealed: Bool,
            airTemp: UFix64?,
            isWeatherRevealed: Bool,
            weather: String?,
            isMoonPhaseRevealed: Bool,
            moonPhase: String?,
            isTideRevealed: Bool,
            tide: String?,
            isBarometricPressureRevealed: Bool,
            barometricPressure: UFix64?,
            isWindSpeedRevealed: Bool,
            windSpeed: UFix64?,
            isWindDirectionRevealed: Bool,
            windDirection: String?,
            isSkyConditionsRevealed: Bool,
            skyConditions: String?,
            isLocationRevealed: Bool,
            location: String?,
            isWaterClarityRevealed: Bool,
            waterClarity: String?,
            isCurrentStrengthRevealed: Bool,
            currentStrength: String?,
            isGearRevealed: Bool,
            gear: String?,
            isBaitLureRevealed: Bool,
            baitLure: String?,
            isTechniqueRevealed: Bool,
            technique: String?,
            isGirthRevealed: Bool,
            girth: UFix64?,
            isFightDurationRevealed: Bool,
            fightDuration: UFix64?,
            isRodTypeRevealed: Bool,
            rodType: String?,
            isReelTypeRevealed: Bool,
            reelType: String?,
            isLineTypeRevealed: Bool,
            lineType: String?,
            isLeaderTypeRevealed: Bool,
            leaderType: String?,
            isHookTypeRevealed: Bool,
            hookType: String?,
            isPresentationRevealed: Bool,
            presentation: String?,
            isRetrieveSpeedRevealed: Bool,
            retrieveSpeed: String?,
            isCatchDepthRevealed: Bool,
            catchDepth: UFix64?
        ) {
            self.fishNFTID = fishNFTID
            self.owner = owner
            self.species = species
            self.scientific = scientific
            self.length = length
            self.weight = weight
            self.timestamp = timestamp
            self.speciesCode = speciesCode
            self.hasRelease = hasRelease

            self.isLongitudeRevealed = isLongitudeRevealed
            self.longitude = isLongitudeRevealed ? longitude : nil
            self.isLatitudeRevealed = isLatitudeRevealed
            self.latitude = isLatitudeRevealed ? latitude : nil
            self.isWaterBodyRevealed = isWaterBodyRevealed
            self.waterBody = isWaterBodyRevealed ? waterBody : nil
            self.isWaterDepthRevealed = isWaterDepthRevealed
            self.waterDepth = isWaterDepthRevealed ? waterDepth : nil
            self.isStructureTypeRevealed = isStructureTypeRevealed
            self.structureType = isStructureTypeRevealed ? structureType : nil
            self.isBottomTypeRevealed = isBottomTypeRevealed
            self.bottomType = isBottomTypeRevealed ? bottomType : nil
            self.isWaterTempRevealed = isWaterTempRevealed
            self.waterTemp = isWaterTempRevealed ? waterTemp : nil
            self.isAirTempRevealed = isAirTempRevealed
            self.airTemp = isAirTempRevealed ? airTemp : nil
            self.isWeatherRevealed = isWeatherRevealed
            self.weather = isWeatherRevealed ? weather : nil
            self.isMoonPhaseRevealed = isMoonPhaseRevealed
            self.moonPhase = isMoonPhaseRevealed ? moonPhase : nil
            self.isTideRevealed = isTideRevealed
            self.tide = isTideRevealed ? tide : nil
            self.isBarometricPressureRevealed = isBarometricPressureRevealed
            self.barometricPressure = isBarometricPressureRevealed ? barometricPressure : nil
            self.isWindSpeedRevealed = isWindSpeedRevealed
            self.windSpeed = isWindSpeedRevealed ? windSpeed : nil
            self.isWindDirectionRevealed = isWindDirectionRevealed
            self.windDirection = isWindDirectionRevealed ? windDirection : nil
            self.isSkyConditionsRevealed = isSkyConditionsRevealed
            self.skyConditions = isSkyConditionsRevealed ? skyConditions : nil
            self.isLocationRevealed = isLocationRevealed
            self.location = isLocationRevealed ? location : nil
            self.isWaterClarityRevealed = isWaterClarityRevealed
            self.waterClarity = isWaterClarityRevealed ? waterClarity : nil
            self.isCurrentStrengthRevealed = isCurrentStrengthRevealed
            self.currentStrength = isCurrentStrengthRevealed ? currentStrength : nil
            self.isGearRevealed = isGearRevealed
            self.gear = isGearRevealed ? gear : nil
            self.isBaitLureRevealed = isBaitLureRevealed
            self.baitLure = isBaitLureRevealed ? baitLure : nil
            self.isTechniqueRevealed = isTechniqueRevealed
            self.technique = isTechniqueRevealed ? technique : nil
            self.isGirthRevealed = isGirthRevealed
            self.girth = isGirthRevealed ? girth : nil
            self.isFightDurationRevealed = isFightDurationRevealed
            self.fightDuration = isFightDurationRevealed ? fightDuration : nil
            self.isRodTypeRevealed = isRodTypeRevealed
            self.rodType = isRodTypeRevealed ? rodType : nil
            self.isReelTypeRevealed = isReelTypeRevealed
            self.reelType = isReelTypeRevealed ? reelType : nil
            self.isLineTypeRevealed = isLineTypeRevealed
            self.lineType = isLineTypeRevealed ? lineType : nil
            self.isLeaderTypeRevealed = isLeaderTypeRevealed
            self.leaderType = isLeaderTypeRevealed ? leaderType : nil
            self.isHookTypeRevealed = isHookTypeRevealed
            self.hookType = isHookTypeRevealed ? hookType : nil
            self.isPresentationRevealed = isPresentationRevealed
            self.presentation = isPresentationRevealed ? presentation : nil
            self.isRetrieveSpeedRevealed = isRetrieveSpeedRevealed
            self.retrieveSpeed = isRetrieveSpeedRevealed ? retrieveSpeed : nil
            self.isCatchDepthRevealed = isCatchDepthRevealed
            self.catchDepth = isCatchDepthRevealed ? catchDepth : nil
        }
    }

    // --- NFT Resource ---
    access(all) resource NFT: NonFungibleToken.NFT, MetadataViews.Resolver {
        access(all) let id: UInt64
        access(all) let metadata: FishCardMetadata
        access(all) let mintedAt: UFix64

        init(
            id: UInt64,
            metadata: FishCardMetadata
        ) {
            self.id = id
            self.metadata = metadata
            self.mintedAt = getCurrentBlock().timestamp
        }

        access(all) fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.ExternalURL>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    // Calculate rarity score based on number of reveals
                    let revealCount = self.countReveals()
                    let rarityLevel = self.calculateRarityLevel(revealCount)
                    
                    return MetadataViews.Display(
                        name: "FishCard #".concat(self.id.toString()),
                        description: "A ".concat(rarityLevel).concat(" rarity card of a ").concat(self.metadata.species),
                        thumbnail: MetadataViews.HTTPFile(url: self.getCardImageURL())
                    )

                case Type<MetadataViews.Traits>():
                    let traits: [MetadataViews.Trait] = []
                    
                    // Core traits
                    traits.append(MetadataViews.Trait(name: "Species", value: self.metadata.species, displayType: "String", rarity: nil))
                    // ... add other core traits ...

                    // Add reveal status for each field
                    traits.append(MetadataViews.Trait(name: "Revealed Fields", value: self.countReveals(), displayType: "Number", rarity: nil))
                    
                    // Add revealed field values
                    if self.metadata.isLongitudeRevealed {
                        traits.append(MetadataViews.Trait(name: "Longitude", value: self.metadata.longitude, displayType: "Number", rarity: nil))
                    }
                    // ... add other revealed fields ...

                    return MetadataViews.Traits(traits)
            }
            return nil
        }

        // Helper to count total reveals
        access(self) fun countReveals(): UInt64 {
            var count: UInt64 = 0
            if self.metadata.isLongitudeRevealed { count = count + 1 }
            if self.metadata.isLatitudeRevealed { count = count + 1 }
            // ... count other reveals ...
            return count
        }

        // Calculate rarity level based on reveals
        access(self) fun calculateRarityLevel(_ revealCount: UInt64): String {
            switch revealCount {
                case 0-5: return "Common"
                case 6-10: return "Uncommon"
                case 11-15: return "Rare"
                case 16-20: return "Epic"
                default: return "Legendary"
            }
        }

        // Generate card image URL based on reveals
        access(self) fun getCardImageURL(): String {
            // TODO: Implement dynamic card image generation based on revealed fields
            return "https://api.derbyfish.flow/cards/".concat(self.id.toString())
        }
    }

    // --- Collection Resource ---
    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        // Standard collection functions
        access(all) fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @FishCardNFT.NFT
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            destroy oldToken
        }

        access(all) fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("missing NFT")
            return <-token
        }

        access(all) fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // --- Minter Resource ---
    access(all) resource Minter {
        // Function to request a new card mint
        access(all) fun requestMint(
            fishNFT: &FishNFT.NFT,
            payment: @FungibleToken.Vault
        ): @Receipt {
            pre {
                let config = FishCardNFT.fishNFTConfigs[fishNFT.id] ?? panic("No configuration for this FishNFT")
                config.isEnabled: "Minting not enabled for this FishNFT"
                config.currentSupply < config.maxSupply: "Max supply reached for this FishNFT"
                payment.balance >= config.mintPrice: "Insufficient payment"
                fishNFT.metadata.allowFishCards: "Fish cards not enabled for this NFT"
            }
            
            // Handle payment
            let vault <- payment as! @FlowToken.Vault
            FishCardNFT.account.storage
                .borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
                .deposit(from: <-vault)

            // Update mint count for address
            let config = FishCardNFT.fishNFTConfigs[fishNFT.id]!
            config.currentSupply = config.currentSupply + 1
            config.addressMintCounts[self.owner?.address ?? panic("No owner")] = 
                (config.addressMintCounts[self.owner?.address ?? panic("No owner")] ?? 0) + 1

            // Request randomness from beacon
            let request <- RandomBeacon.requestRandomness()
            
            return <- create Receipt(
                betAmount: config.mintPrice,
                request: <-request
            )
        }

        // Function to reveal and mint the card
        access(all) fun revealAndMint(
            request: @RandomBeacon.Request,
            fishNFT: &FishNFT.NFT,
            recipient: Address
        ): @NFT {
            pre {
                let config = FishCardNFT.fishNFTConfigs[fishNFT.id] ?? panic("No configuration for this FishNFT")
                config.isEnabled: "Minting not enabled for this FishNFT"
                
                // Check reveal delay
                getCurrentBlock().timestamp >= request.blockHeight + config.revealDelay:
                    "Must wait for reveal delay to pass"
            }

            // Get random value from beacon
            let random = request.random()
            destroy request

            // Get config for probability checks
            let config = FishCardNFT.fishNFTConfigs[fishNFT.id]!

            // Derive unique random values for each field
            let isLongitudeRevealed = deriveRandomForField(random, "longitude") <= config.fieldProbabilities["longitude"]!
            let isLatitudeRevealed = deriveRandomForField(random, "latitude") <= config.fieldProbabilities["latitude"]!
            let isWaterBodyRevealed = deriveRandomForField(random, "waterBody") <= config.fieldProbabilities["waterBody"]!
            let isWaterDepthRevealed = deriveRandomForField(random, "waterDepth") <= config.fieldProbabilities["waterDepth"]!
            let isStructureTypeRevealed = deriveRandomForField(random, "structureType") <= config.fieldProbabilities["structureType"]!
            let isBottomTypeRevealed = deriveRandomForField(random, "bottomType") <= config.fieldProbabilities["bottomType"]!
            let isWaterTempRevealed = deriveRandomForField(random, "waterTemp") <= config.fieldProbabilities["waterTemp"]!
            let isAirTempRevealed = deriveRandomForField(random, "airTemp") <= config.fieldProbabilities["airTemp"]!
            let isWeatherRevealed = deriveRandomForField(random, "weather") <= config.fieldProbabilities["weather"]!
            let isMoonPhaseRevealed = deriveRandomForField(random, "moonPhase") <= config.fieldProbabilities["moonPhase"]!
            let isTideRevealed = deriveRandomForField(random, "tide") <= config.fieldProbabilities["tide"]!
            let isBarometricPressureRevealed = deriveRandomForField(random, "barometricPressure") <= config.fieldProbabilities["barometricPressure"]!
            let isWindSpeedRevealed = deriveRandomForField(random, "windSpeed") <= config.fieldProbabilities["windSpeed"]!
            let isWindDirectionRevealed = deriveRandomForField(random, "windDirection") <= config.fieldProbabilities["windDirection"]!
            let isSkyConditionsRevealed = deriveRandomForField(random, "skyConditions") <= config.fieldProbabilities["skyConditions"]!
            let isLocationRevealed = deriveRandomForField(random, "location") <= config.fieldProbabilities["location"]!
            let isWaterClarityRevealed = deriveRandomForField(random, "waterClarity") <= config.fieldProbabilities["waterClarity"]!
            let isCurrentStrengthRevealed = deriveRandomForField(random, "currentStrength") <= config.fieldProbabilities["currentStrength"]!
            let isGearRevealed = deriveRandomForField(random, "gear") <= config.fieldProbabilities["gear"]!
            let isBaitLureRevealed = deriveRandomForField(random, "baitLure") <= config.fieldProbabilities["baitLure"]!
            let isTechniqueRevealed = deriveRandomForField(random, "technique") <= config.fieldProbabilities["technique"]!
            let isGirthRevealed = deriveRandomForField(random, "girth") <= config.fieldProbabilities["girth"]!
            let isFightDurationRevealed = deriveRandomForField(random, "fightDuration") <= config.fieldProbabilities["fightDuration"]!
            let isRodTypeRevealed = deriveRandomForField(random, "rodType") <= config.fieldProbabilities["rodType"]!
            let isReelTypeRevealed = deriveRandomForField(random, "reelType") <= config.fieldProbabilities["reelType"]!
            let isLineTypeRevealed = deriveRandomForField(random, "lineType") <= config.fieldProbabilities["lineType"]!
            let isLeaderTypeRevealed = deriveRandomForField(random, "leaderType") <= config.fieldProbabilities["leaderType"]!
            let isHookTypeRevealed = deriveRandomForField(random, "hookType") <= config.fieldProbabilities["hookType"]!
            let isPresentationRevealed = deriveRandomForField(random, "presentation") <= config.fieldProbabilities["presentation"]!
            let isRetrieveSpeedRevealed = deriveRandomForField(random, "retrieveSpeed") <= config.fieldProbabilities["retrieveSpeed"]!
            let isCatchDepthRevealed = deriveRandomForField(random, "catchDepth") <= config.fieldProbabilities["catchDepth"]!

            // Create metadata with reveal results
            let metadata = FishCardMetadata(
                fishNFTID: fishNFT.id,
                owner: recipient,
                species: fishNFT.metadata.species,
                scientific: fishNFT.metadata.scientific,
                length: fishNFT.metadata.length,
                weight: fishNFT.metadata.weight,
                timestamp: fishNFT.metadata.timestamp,
                speciesCode: fishNFT.metadata.speciesCode,
                hasRelease: fishNFT.metadata.hasRelease,
                
                // Set reveal flags and values
                isLongitudeRevealed: isLongitudeRevealed,
                longitude: isLongitudeRevealed ? fishNFT.metadata.longitude : nil,
                
                isLatitudeRevealed: isLatitudeRevealed,
                latitude: isLatitudeRevealed ? fishNFT.metadata.latitude : nil,
                
                isWaterBodyRevealed: isWaterBodyRevealed,
                waterBody: isWaterBodyRevealed ? fishNFT.metadata.waterBody : nil,
                
                isWaterDepthRevealed: isWaterDepthRevealed,
                waterDepth: isWaterDepthRevealed ? fishNFT.metadata.waterDepth : nil,
                
                isStructureTypeRevealed: isStructureTypeRevealed,
                structureType: isStructureTypeRevealed ? fishNFT.metadata.structureType : nil,
                
                isBottomTypeRevealed: isBottomTypeRevealed,
                bottomType: isBottomTypeRevealed ? fishNFT.metadata.bottomType : nil,
                
                isWaterTempRevealed: isWaterTempRevealed,
                waterTemp: isWaterTempRevealed ? fishNFT.metadata.waterTemp : nil,
                
                isAirTempRevealed: isAirTempRevealed,
                airTemp: isAirTempRevealed ? fishNFT.metadata.airTemp : nil,
                
                isWeatherRevealed: isWeatherRevealed,
                weather: isWeatherRevealed ? fishNFT.metadata.weather : nil,
                
                isMoonPhaseRevealed: isMoonPhaseRevealed,
                moonPhase: isMoonPhaseRevealed ? fishNFT.metadata.moonPhase : nil,
                
                isTideRevealed: isTideRevealed,
                tide: isTideRevealed ? fishNFT.metadata.tide : nil,
                
                isBarometricPressureRevealed: isBarometricPressureRevealed,
                barometricPressure: isBarometricPressureRevealed ? fishNFT.metadata.barometricPressure : nil,
                
                isWindSpeedRevealed: isWindSpeedRevealed,
                windSpeed: isWindSpeedRevealed ? fishNFT.metadata.windSpeed : nil,
                
                isWindDirectionRevealed: isWindDirectionRevealed,
                windDirection: isWindDirectionRevealed ? fishNFT.metadata.windDirection : nil,
                
                isSkyConditionsRevealed: isSkyConditionsRevealed,
                skyConditions: isSkyConditionsRevealed ? fishNFT.metadata.skyConditions : nil,
                
                isLocationRevealed: isLocationRevealed,
                location: isLocationRevealed ? fishNFT.metadata.location : nil,
                
                isWaterClarityRevealed: isWaterClarityRevealed,
                waterClarity: isWaterClarityRevealed ? fishNFT.metadata.waterClarity : nil,
                
                isCurrentStrengthRevealed: isCurrentStrengthRevealed,
                currentStrength: isCurrentStrengthRevealed ? fishNFT.metadata.currentStrength : nil,
                
                isGearRevealed: isGearRevealed,
                gear: isGearRevealed ? fishNFT.metadata.gear : nil,
                
                isBaitLureRevealed: isBaitLureRevealed,
                baitLure: isBaitLureRevealed ? fishNFT.metadata.baitLure : nil,
                
                isTechniqueRevealed: isTechniqueRevealed,
                technique: isTechniqueRevealed ? fishNFT.metadata.technique : nil,
                
                isGirthRevealed: isGirthRevealed,
                girth: isGirthRevealed ? fishNFT.metadata.girth : nil,
                
                isFightDurationRevealed: isFightDurationRevealed,
                fightDuration: isFightDurationRevealed ? fishNFT.metadata.fightDuration : nil,
                
                isRodTypeRevealed: isRodTypeRevealed,
                rodType: isRodTypeRevealed ? fishNFT.metadata.rodType : nil,
                
                isReelTypeRevealed: isReelTypeRevealed,
                reelType: isReelTypeRevealed ? fishNFT.metadata.reelType : nil,
                
                isLineTypeRevealed: isLineTypeRevealed,
                lineType: isLineTypeRevealed ? fishNFT.metadata.lineType : nil,
                
                isLeaderTypeRevealed: isLeaderTypeRevealed,
                leaderType: isLeaderTypeRevealed ? fishNFT.metadata.leaderType : nil,
                
                isHookTypeRevealed: isHookTypeRevealed,
                hookType: isHookTypeRevealed ? fishNFT.metadata.hookType : nil,
                
                isPresentationRevealed: isPresentationRevealed,
                presentation: isPresentationRevealed ? fishNFT.metadata.presentation : nil,
                
                isRetrieveSpeedRevealed: isRetrieveSpeedRevealed,
                retrieveSpeed: isRetrieveSpeedRevealed ? fishNFT.metadata.retrieveSpeed : nil,
                
                isCatchDepthRevealed: isCatchDepthRevealed,
                catchDepth: isCatchDepthRevealed ? fishNFT.metadata.catchDepth : nil
            )

            // Create and return the NFT
            let newNFT <- create NFT(
                id: FishCardNFT.totalSupply,
                metadata: metadata
            )
            
            FishCardNFT.totalSupply = FishCardNFT.totalSupply + 1
            
            emit Minted(id: newNFT.id, fishNFTID: fishNFT.id)
            
            return <-newNFT
        }

        // Helper function to derive random number for a specific field
        access(contract) fun deriveRandomForField(_ seed: [UInt8], _ field: String): UFix64 {
            // Hash the seed with the field name to get unique random per field
            let fieldHash = HashAlgorithm.SHA3_256.hash(seed.concat(field.utf8))
            // Convert last 8 bytes to UFix64 between 0.0 and 1.0
            let value = UFix64(fieldHash[24]) + // most significant byte
                       UFix64(fieldHash[25]) / 256.0 +
                       UFix64(fieldHash[26]) / 65536.0 +
                       UFix64(fieldHash[27]) / 16777216.0 +
                       UFix64(fieldHash[28]) / 4294967296.0 +
                       UFix64(fieldHash[29]) / 1099511627776.0 +
                       UFix64(fieldHash[30]) / 281474976710656.0 +
                       UFix64(fieldHash[31]) / 72057594037927936.0 // least significant byte
            return value / 256.0 // Normalize to 0.0-1.0
        }
    }

    init() {
        self.CollectionStoragePath = /storage/FishCardNFTCollection
        self.CollectionPublicPath = /public/FishCardNFTCollection
        self.MinterStoragePath = /storage/FishCardNFTMinter
        self.ConfigManagerStoragePath = /storage/FishCardNFTConfigManager
        
        self.totalSupply = 0
        self.maxSupply = 1000
        self.mintPrice = 100.0
        self.paused = false

        // Initialize new minting configurations
        self.mintingPhase = "closed"
        self.maxMintsPerAddress = 5
        self.addressMintCounts = {}
        self.whitelistedAddresses = {}
        self.preSalePrice = 80.0
        self.bulkMintDiscount = 0.1  // 10% discount
        self.royaltyPercent = 0.05   // 5% royalty
        self.royaltyRecipient = self.account.address
        self.mintStartTime = getCurrentBlock().timestamp
        self.mintEndTime = nil
        self.revealDelay = 86400.0  // 24 hours in seconds

        // Initialize default field probabilities
        self.fieldProbabilities = {
            // Location data
            "longitude": 0.3,
            "latitude": 0.3,
            "waterBody": 0.8,
            "waterDepth": 0.5,
            "structureType": 0.4,
            "bottomType": 0.4,
            
            // Environmental data
            "waterTemp": 0.6,
            "airTemp": 0.6,
            "weather": 0.7,
            "moonPhase": 0.5,
            "tide": 0.5,
            "barometricPressure": 0.4,
            "windSpeed": 0.6,
            "windDirection": 0.6,
            "skyConditions": 0.7,
            
            // Angler data
            "location": 0.4,
            "waterClarity": 0.5,
            "currentStrength": 0.5,
            "gear": 0.3,
            "baitLure": 0.3,
            "technique": 0.4,
            "girth": 0.6,
            "fightDuration": 0.5,
            "rodType": 0.3,
            "reelType": 0.3,
            "lineType": 0.3,
            "leaderType": 0.3,
            "hookType": 0.3,
            "presentation": 0.4,
            "retrieveSpeed": 0.4,
            "catchDepth": 0.5
        }

        // Create admin resource
        let admin <- create Admin()
        self.account.save(<-admin, to: self.ConfigManagerStoragePath)

        // Create minter resource
        let minter <- create Minter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        // Create collection resource
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // Create public capability for the collection
        self.account.link<&{NonFungibleToken.CollectionPublic}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}