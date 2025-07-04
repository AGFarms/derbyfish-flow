import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FungibleToken"

access(all) contract FishNFT: NonFungibleToken {

    // Define public interface for species coin redemption
    access(all) resource interface SpeciesCoinRedeemer {
        access(all) fun redeemCatch(fishData: {String: AnyStruct}, angler: Address): @{FungibleToken.Vault}
    }

    // DESIGN NOTES:
    // This NFT contract implements strict immutability - once a catch is minted,
    // none of its data can be modified. This ensures:
    // 1. Data integrity of verified catches
    // 2. Fair competition and prize distribution
    // 3. Permanent historical record of catches
    // 4. Trust in the DerbyFish ecosystem
    //
    // All catch data, including:
    // - Core catch details
    // - Competition results
    // - Location data
    // - Environmental conditions
    // - Verification status
    // Must be provided at mint time and cannot be updated.

    // SPECIES COIN INTEGRATION - Simple registry approach
    access(all) var speciesRegistry: {String: Address}  // speciesCode -> contract address
    access(all) var totalFishCaught: UInt64
    
    // SPECIES COIN REDEMPTION TRACKING - Prevent double redemption
    access(all) var speciesCoinsRedeemed: {UInt64: Bool}  // fishNFTId -> has been redeemed

    // Storage paths
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let SpeciesCoinRedeemerPath: PublicPath
    access(all) let VaultReceiverPath: PublicPath

    // Events
    access(all) event SpeciesRegistered(speciesCode: String, contractAddress: Address)

    access(all) event FishMinted(
        id: UInt64,
        recipient: Address,
        species: String,
        scientific: String,
        length: UFix64,
        latitude: Fix64,
        longitude: Fix64,
        timestamp: UFix64,
        speciesCode: String
    )

    access(all) struct FishMetadata {
        // PUBLIC CORE DATA - Always visible to everyone
        access(all) let owner: Address              // Owner of the NFT
        access(all) let species: String              // Common name
        access(all) let scientific: String           // Scientific name
        access(all) let length: UFix64               // Length in inches
        access(all) let weight: UFix64?              // Weight in pounds if measured
        access(all) let timestamp: UFix64            // When caught
        access(all) let speciesCode: String          // Required species code for minting
        access(all) let hasRelease: Bool             // Whether fish was released
        access(all) let qualityScore: UFix64?        // DerbyFish quality score (1-100)
        access(all) let waterBody: String?           // Lake, river, ocean name from location API
        access(all) var allowFishCards: Bool         // Whether this fish can be used to mint FishCards (one-way switch)
        
        // COMPETITION DATA - Public competition results
        access(all) let competitions: {UInt64: {String: UInt64}}  // Map of derbyId -> {leaderboardId: placement}
        access(all) let prizesWon: [String]                      // List of prizes won with this catch
        access(all) let totalPrizeValue: UFix64?                 // Total value of prizes won (if applicable)

        // DERBYFISH SANCTIONING BODY DATA - Added during verification
        access(all) let verificationLevel: String    // Level of verification (basic, enhanced, tournament)
        access(all) let verifiedBy: Address          // Address of verifier
        access(all) let verifiedAt: UFix64           // When verified
        access(all) let competitionId: String?       // If caught during competition
        access(all) let recordStatus: String?        // If this is a record catch (state, lake, etc)
        access(all) let certificationLevel: String?  // Certification level of the catch

        // REQUIRED MEDIA - For verification
        access(all) let bumpShotUrl: String          // Bump board measurement photo
        access(all) let heroShotUrl: String          // Beauty shot of catch
        access(all) let bumpHash: String             // Hash of bump shot
        access(all) let heroHash: String             // Hash of hero shot
        access(all) let releaseVideoUrl: String?     // Optional release video URL
        access(all) let releaseHash: String?         // Release video hash if exists

        // PRIVATE LOCATION DATA - Only visible to owner and contract admin
        access(contract) let longitude: Fix64             // Exact longitude from GPS
        access(contract) let latitude: Fix64              // Exact latitude from GPS
        access(contract) let waterTemp: UFix64?           // Temperature in Fahrenheit from weather API
        access(contract) let airTemp: UFix64?             // Temperature in Fahrenheit from weather API
        access(contract) let weather: String?             // Weather conditions from API
        access(contract) let moonPhase: String?           // Moon phase calculated by app
        access(contract) let tide: String?                // Tide data if coastal location
        access(contract) let barometricPressure: UFix64?  // Barometric pressure from weather API
        access(contract) let windSpeed: UFix64?           // Wind speed from weather API
        access(contract) let windDirection: String?       // Wind direction from weather API
        access(contract) let skyConditions: String?       // Weather conditions from API
        access(contract) let waterDepth: UFix64?          // Depth from bathymetric data if available
        access(contract) let structureType: String?       // Structure type from location data
        access(contract) let bottomType: String?          // Bottom composition from location data

        // PRIVATE ANGLER DATA - Only visible to owner and contract admin
        access(contract) let location: String?            // Named spot/location
        access(contract) let waterClarity: String?        // Water visibility/clarity
        access(contract) let currentStrength: String?     // Water current strength
        access(contract) let gear: String?                // Equipment used
        access(contract) let baitLure: String?            // Specific bait or lure
        access(contract) let fightDuration: UFix64?       // Fight duration in seconds
        access(contract) let technique: String?           // Fishing technique used
        access(contract) let girth: UFix64?               // Girth in inches if measured
        access(contract) let rodType: String?             // Type of rod used
        access(contract) let reelType: String?            // Type of reel used
        access(contract) let lineType: String?            // Type of line used
        access(contract) let leaderType: String?          // Type of leader used
        access(contract) let hookType: String?            // Type of hook used
        access(contract) let presentation: String?        // How the bait/lure was presented
        access(contract) let retrieveSpeed: String?       // Speed of retrieve
        access(contract) let catchDepth: UFix64?          // Depth fish was hooked at

        // Function to get private data if caller is authorized
        access(all) fun getPrivateData(caller: Address): {String: AnyStruct}? {
            // Only allow the NFT owner or contract admin to access private data
            if caller != self.owner && caller != FishNFT.account.address {
                return nil
            }

            return {
                // Location data
                "longitude": self.longitude,
                "latitude": self.latitude,
                "waterTemp": self.waterTemp,
                "airTemp": self.airTemp,
                "weather": self.weather,
                "moonPhase": self.moonPhase,
                "tide": self.tide,
                "barometricPressure": self.barometricPressure,
                "windSpeed": self.windSpeed,
                "windDirection": self.windDirection,
                "skyConditions": self.skyConditions,
                "waterDepth": self.waterDepth,
                "structureType": self.structureType,
                "bottomType": self.bottomType,

                // Angler data
                "location": self.location,
                "waterClarity": self.waterClarity,
                "currentStrength": self.currentStrength,
                "gear": self.gear,
                "baitLure": self.baitLure,
                "fightDuration": self.fightDuration,
                "technique": self.technique,
                "girth": self.girth,
                "rodType": self.rodType,
                "reelType": self.reelType,
                "lineType": self.lineType,
                "leaderType": self.leaderType,
                "hookType": self.hookType,
                "presentation": self.presentation,
                "retrieveSpeed": self.retrieveSpeed,
                "catchDepth": self.catchDepth
            }
        }

        // Function to enable fish card minting - can only be called once
        access(all) fun enableFishCards() {
            pre {
                !self.allowFishCards: "Fish card minting has already been enabled"
            }
            self.allowFishCards = true
        }

        init(
            // PUBLIC CORE DATA
            owner: Address,
            species: String,
            scientific: String,
            length: UFix64,
            weight: UFix64?,
            timestamp: UFix64,
            speciesCode: String,
            hasRelease: Bool,

            // DERBY & COMPETITION DATA
            competitions: {UInt64: {String: UInt64}},
            prizesWon: [String],
            totalPrizeValue: UFix64?,
            
            // DERBYFISH SANCTIONING BODY DATA
            verificationLevel: String,
            verifiedBy: Address,
            verifiedAt: UFix64,
            competitionId: String?,
            recordStatus: String?,
            certificationLevel: String?,
            qualityScore: UFix64?,

            // DERBYFISH APP-PROVIDED DATA
            longitude: Fix64,
            latitude: Fix64,
            waterTemp: UFix64?,
            airTemp: UFix64?,
            weather: String?,
            moonPhase: String?,
            tide: String?,
            waterBody: String?,
            barometricPressure: UFix64?,
            windSpeed: UFix64?,
            windDirection: String?,
            skyConditions: String?,
            waterDepth: UFix64?,
            structureType: String?,
            bottomType: String?,

            // REQUIRED MEDIA
            bumpShotUrl: String,
            heroShotUrl: String,
            bumpHash: String,
            heroHash: String,
            releaseVideoUrl: String?,
            releaseHash: String?,

            // ANGLER-PROVIDED LOCATION DATA
            location: String?,
            waterClarity: String?,
            currentStrength: String?,
            
            // ANGLER-PROVIDED TECHNIQUE DATA
            gear: String?,
            baitLure: String?,
            fightDuration: UFix64?,
            technique: String?,
            girth: UFix64?,
            rodType: String?,
            reelType: String?,
            lineType: String?,
            leaderType: String?,
            hookType: String?,
            presentation: String?,
            retrieveSpeed: String?,
            catchDepth: UFix64?
        ) {
            // PUBLIC CORE DATA
            self.owner = owner
            self.species = species
            self.scientific = scientific
            self.length = length
            self.weight = weight
            self.timestamp = timestamp
            self.speciesCode = speciesCode
            self.hasRelease = hasRelease
            self.allowFishCards = false  // Initialize as false by default

            // DERBY & COMPETITION DATA
            self.competitions = competitions
            self.prizesWon = prizesWon
            self.totalPrizeValue = totalPrizeValue
            
            // DERBYFISH SANCTIONING BODY DATA
            self.verificationLevel = verificationLevel
            self.verifiedBy = verifiedBy
            self.verifiedAt = verifiedAt
            self.competitionId = competitionId
            self.recordStatus = recordStatus
            self.certificationLevel = certificationLevel
            self.qualityScore = qualityScore

            // DERBYFISH APP-PROVIDED DATA
            self.longitude = longitude
            self.latitude = latitude
            self.waterTemp = waterTemp
            self.airTemp = airTemp
            self.weather = weather
            self.moonPhase = moonPhase
            self.tide = tide
            self.waterBody = waterBody
            self.barometricPressure = barometricPressure
            self.windSpeed = windSpeed
            self.windDirection = windDirection
            self.skyConditions = skyConditions
            self.waterDepth = waterDepth
            self.structureType = structureType
            self.bottomType = bottomType

            // REQUIRED MEDIA
            self.bumpShotUrl = bumpShotUrl
            self.heroShotUrl = heroShotUrl
            self.bumpHash = bumpHash
            self.heroHash = heroHash
            self.releaseVideoUrl = releaseVideoUrl
            self.releaseHash = releaseHash
            
            // ANGLER-PROVIDED LOCATION DATA
            self.location = location
            self.waterClarity = waterClarity
            self.currentStrength = currentStrength
            
            // ANGLER-PROVIDED TECHNIQUE DATA
            self.gear = gear
            self.baitLure = baitLure
            self.fightDuration = fightDuration
            self.technique = technique
            self.girth = girth
            self.rodType = rodType
            self.reelType = reelType
            self.lineType = lineType
            self.leaderType = leaderType
            self.hookType = hookType
            self.presentation = presentation
            self.retrieveSpeed = retrieveSpeed
            self.catchDepth = catchDepth
        }
    }

    access(all) resource NFT: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) let metadata: FishMetadata
        access(all) let mintedBy: Address
        access(all) let mintedAt: UFix64

        // Function to enable fish card minting - can only be called by owner
        access(all) fun enableFishCards(caller: Address) {
            pre {
                caller == self.metadata.owner: "Only the NFT owner can enable fish card minting"
            }
            self.metadata.enableFishCards()
        }

        init(
            id: UInt64,
            metadata: FishMetadata,
            mintedBy: Address
        ) {
            self.id = id
            self.metadata = metadata
            self.mintedBy = mintedBy
            self.mintedAt = getCurrentBlock().timestamp
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Traits>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "DerbyFish Catch - ".concat(self.metadata.species),
                        description: "A verified catch of ".concat(self.metadata.species).concat(" (").concat(self.metadata.scientific).concat(") measuring ").concat(self.metadata.length.toString()).concat(" inches"),
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.metadata.heroShotUrl
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://derbyfish.flow.org/fish/".concat(self.id.toString()))
                case Type<MetadataViews.Traits>():
                    let traits: [MetadataViews.Trait] = [
                        // PUBLIC CORE DATA
                        MetadataViews.Trait(
                            name: "Species",
                            value: self.metadata.species,
                            displayType: "String",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Scientific Name",
                            value: self.metadata.scientific,
                            displayType: "String",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Length",
                            value: self.metadata.length,
                            displayType: "Number",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Weight",
                            value: self.metadata.weight,
                            displayType: "Number",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Catch Date",
                            value: self.metadata.timestamp,
                            displayType: "Date",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Has Release",
                            value: self.metadata.hasRelease,
                            displayType: "Boolean",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Quality Score",
                            value: self.metadata.qualityScore,
                            displayType: "Number",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Water Body",
                            value: self.metadata.waterBody,
                            displayType: "String",
                            rarity: nil
                        ),
                        // VERIFICATION DATA
                        MetadataViews.Trait(
                            name: "Verification Level",
                            value: self.metadata.verificationLevel,
                            displayType: "String",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Verified By",
                            value: self.metadata.verifiedBy,
                            displayType: "Address",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Verified At",
                            value: self.metadata.verifiedAt,
                            displayType: "Date",
                            rarity: nil
                        )
                    ]

                    // Add optional verification data if present
                    if let competitionId = self.metadata.competitionId {
                        traits.append(
                            MetadataViews.Trait(
                                name: "Competition ID",
                                value: competitionId,
                                displayType: "String",
                                rarity: nil
                            )
                        )
                    }

                    if let recordStatus = self.metadata.recordStatus {
                        traits.append(
                            MetadataViews.Trait(
                                name: "Record Status",
                                value: recordStatus,
                                displayType: "String",
                                rarity: nil
                            )
                        )
                    }

                    if let certificationLevel = self.metadata.certificationLevel {
                        traits.append(
                            MetadataViews.Trait(
                                name: "Certification Level",
                                value: certificationLevel,
                                displayType: "String",
                                rarity: nil
                            )
                        )
                    }

                    // Add competition data if any exists
                    if self.metadata.competitions.length > 0 {
                        for derbyId in self.metadata.competitions.keys {
                            let placements = self.metadata.competitions[derbyId]!
                            for leaderboardId in placements.keys {
                                traits.append(
                                    MetadataViews.Trait(
                                        name: "Derby ".concat(derbyId.toString()).concat(" - Leaderboard ").concat(leaderboardId),
                                        value: placements[leaderboardId],
                                        displayType: "Number",
                                        rarity: nil
                                    )
                                )
                            }
                        }
                    }

                    // Add prize information if any
                    if self.metadata.prizesWon.length > 0 {
                        traits.append(
                            MetadataViews.Trait(
                                name: "Prizes Won",
                                value: self.metadata.prizesWon,
                                displayType: "String[]",
                                rarity: nil
                            )
                        )

                        if let prizeValue = self.metadata.totalPrizeValue {
                            traits.append(
                                MetadataViews.Trait(
                                    name: "Total Prize Value",
                                    value: prizeValue,
                                    displayType: "Number",
                                    rarity: nil
                                )
                            )
                        }
                    }

                    return MetadataViews.Traits(traits)
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-FishNFT.createEmptyCollection(nftType: Type<@FishNFT.NFT>())
        }
    }

    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init() {
            self.ownedNFTs <- {}
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@FishNFT.NFT>()] = true
            return supportedTypes
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@FishNFT.NFT>()
        }

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("Could not withdraw an NFT with the provided ID from the collection")

            return <-token
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @FishNFT.NFT
            let id = token.id

            let oldToken <- self.ownedNFTs[token.id] <- token
            destroy oldToken
        }

        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) view fun getLength(): Int {
            return self.ownedNFTs.length
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)
        }

        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            if let nft = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}? {
                return nft as &{ViewResolver.Resolver}
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-FishNFT.createEmptyCollection(nftType: Type<@FishNFT.NFT>())
        }
    }

    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    access(all) resource NFTMinter {
        access(all) var nextID: UInt64

        init() {
            self.nextID = 1
        }

        access(all) fun mintNFT(
            recipient: Address,
            metadata: FishMetadata
        ): @FishNFT.NFT {
            let newNFT <- create FishNFT.NFT(
                id: self.nextID,
                metadata: metadata,
                mintedBy: FishNFT.account.address
            )

            emit FishMinted(
                id: self.nextID,
                recipient: recipient,
                species: metadata.species,
                scientific: metadata.scientific,
                length: metadata.length,
                latitude: metadata.latitude,
                longitude: metadata.longitude,
                timestamp: metadata.timestamp,
                speciesCode: metadata.speciesCode
            )

            // Update total fish caught counter
            FishNFT.totalFishCaught = FishNFT.totalFishCaught + 1

            // Process species coin minting (speciesCode is now required)
            if let contractAddress = FishNFT.speciesRegistry[metadata.speciesCode] {
                    FishNFT.mintSpeciesCoins(
                        fishNFTId: self.nextID, 
                    speciesCode: metadata.speciesCode, 
                        angler: recipient,
                        contractAddress: contractAddress
                    )
            } else {
                panic("Species code ".concat(metadata.speciesCode).concat(" not registered"))
            }

            self.nextID = self.nextID + 1

            return <-newNFT
        }
        
        // Enhanced mint function with species validation
        access(all) fun mintNFTWithSpeciesValidation(
            recipient: Address,
            species: String,
            scientific: String,
            length: UFix64,
            weight: UFix64?,
            timestamp: UFix64,
            speciesCode: String,
            hasRelease: Bool,
            bumpShotUrl: String,
            heroShotUrl: String,
            bumpHash: String,
            heroHash: String,
            releaseVideoUrl: String?,
            releaseHash: String?,
            longitude: Fix64,
            latitude: Fix64,
            waterBody: String?
        ): @FishNFT.NFT {
            
            // Create metadata with minimal required fields
            let metadata = FishMetadata(
                // PUBLIC CORE DATA
                owner: recipient,
                species: species,
                scientific: scientific,
                length: length,
                weight: weight,
                timestamp: timestamp,
                speciesCode: speciesCode,
                hasRelease: hasRelease,

                // COMPETITION DATA - Empty initially
                competitions: {},
                prizesWon: [],
                totalPrizeValue: nil,
                
                // VERIFICATION DATA - Basic verification initially
                verificationLevel: "basic",
                verifiedBy: FishNFT.account.address,
                verifiedAt: getCurrentBlock().timestamp,
                competitionId: nil,
                recordStatus: nil,
                certificationLevel: nil,
                qualityScore: nil,

                // LOCATION & ENVIRONMENTAL DATA
                longitude: longitude,
                latitude: latitude,
                waterTemp: nil,
                airTemp: nil,
                weather: nil,
                moonPhase: nil,
                tide: nil,
                waterBody: waterBody,
                barometricPressure: nil,
                windSpeed: nil,
                windDirection: nil,
                skyConditions: nil,
                waterDepth: nil,
                structureType: nil,
                bottomType: nil,

                // MEDIA
                bumpShotUrl: bumpShotUrl,
                heroShotUrl: heroShotUrl,
                bumpHash: bumpHash,
                heroHash: heroHash,
                releaseVideoUrl: releaseVideoUrl,
                releaseHash: releaseHash,

                // ANGLER DATA - Empty initially
                location: nil,
                waterClarity: nil,
                currentStrength: nil,
                gear: nil,
                baitLure: nil,
                fightDuration: nil,
                technique: nil,
                girth: nil,
                rodType: nil,
                reelType: nil,
                lineType: nil,
                leaderType: nil,
                hookType: nil,
                presentation: nil,
                retrieveSpeed: nil,
                catchDepth: nil
            )
            
            return <- self.mintNFT(recipient: recipient, metadata: metadata)
        }

        access(all) fun mintNFTToCollection(
            recipient: &{NonFungibleToken.Collection},
            metadata: FishMetadata
        ) {
            let nft <- self.mintNFT(
                recipient: recipient.owner?.address ?? FishNFT.account.address,
                metadata: metadata
            )
            recipient.deposit(token: <-nft)
        }
    }

    // Public query functions
    access(all) view fun getTotalFishCaught(): UInt64 {
        return self.totalFishCaught
    }

    // Contract Views (required by NonFungibleToken interface)
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: self.CollectionStoragePath,
                    publicPath: self.CollectionPublicPath,
                    publicCollection: Type<&FishNFT.Collection>(),
                    publicLinkedType: Type<&FishNFT.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-FishNFT.createEmptyCollection(nftType: Type<@FishNFT.NFT>())
                    })
                )
            case Type<MetadataViews.NFTCollectionDisplay>():
                return MetadataViews.NFTCollectionDisplay(
                    name: "DerbyFish Catches",
                    description: "Verified fishing catches in the DerbyFish ecosystem",
                    externalURL: MetadataViews.ExternalURL("https://derby.fish"),
                    squareImage: MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: "https://derby.fish/images/logo-square.png"),
                        mediaType: "image/png"
                    ),
                    bannerImage: MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: "https://derby.fish/images/banner.png"),
                        mediaType: "image/png"
                    ),
                    socials: {
                        "website": MetadataViews.ExternalURL("https://derby.fish"),
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/derby_fish")
                    }
                )
        }
        return nil
    }

    // Simple species registry functions
    access(all) fun registerSpecies(speciesCode: String, contractAddress: Address) {
        self.speciesRegistry[speciesCode] = contractAddress
        emit SpeciesRegistered(speciesCode: speciesCode, contractAddress: contractAddress)
    }

    access(all) fun getSpeciesAddress(speciesCode: String): Address? {
        return self.speciesRegistry[speciesCode]
    }

    access(all) view fun getAllRegisteredSpecies(): {String: Address} {
        return self.speciesRegistry
    }

    // SPECIES COIN REDEMPTION FUNCTIONS - Track per-NFT redemption status
    access(all) view fun hasBeenRedeemedForCoin(fishNFTId: UInt64): Bool {
        return self.speciesCoinsRedeemed[fishNFTId] ?? false
    }

    access(all) fun markAsRedeemedForCoin(fishNFTId: UInt64) {
        self.speciesCoinsRedeemed[fishNFTId] = true
    }

    access(all) view fun getRedeemedNFTCount(): Int {
        return self.speciesCoinsRedeemed.length
    }

    access(all) view fun getAllRedeemedNFTIds(): [UInt64] {
        return self.speciesCoinsRedeemed.keys
    }

    // Species coin redemption function
    access(all) fun redeemForSpeciesCoin(fishNFTId: UInt64, speciesCode: String, angler: Address, contractAddress: Address) {
        // Check if NFT has already been redeemed
        if self.hasBeenRedeemedForCoin(fishNFTId: fishNFTId) {
            log("Fish NFT #".concat(fishNFTId.toString()).concat(" has already been redeemed for a species coin"))
            return
        }
        
        // Mark as redeemed BEFORE calling external contract (prevent reentrancy)
        self.markAsRedeemedForCoin(fishNFTId: fishNFTId)
        
        // For now, just emit an event that species coin redemption was requested
        // The actual redemption logic will be handled by a separate transaction
        // This keeps the FishNFT contract simple and decoupled
        log("Species coin redemption requested for: ".concat(speciesCode).concat(" to angler: ").concat(angler.toString()).concat(" for NFT #").concat(fishNFTId.toString()))
    }

    // Species coin minting function
    access(all) fun mintSpeciesCoins(fishNFTId: UInt64, speciesCode: String, angler: Address, contractAddress: Address) {
        // Check if species coins have already been minted for this NFT
        if self.hasBeenRedeemedForCoin(fishNFTId: fishNFTId) {
            log("Species coins already redeemed for Fish NFT #".concat(fishNFTId.toString()).concat(" - skipping"))
            return
        }
        
        // Mark as redeemed BEFORE calling external contract (prevent reentrancy)
        self.markAsRedeemedForCoin(fishNFTId: fishNFTId)
        
        // Get the species coin contract account
        let speciesCoinAccount = getAccount(contractAddress)
        
        // Get the species coin redeemer capability
        if let redeemer = speciesCoinAccount.capabilities
            .borrow<&{SpeciesCoinRedeemer}>(self.SpeciesCoinRedeemerPath) {
            
            // Prepare fish data for redemption
            let fishData: {String: AnyStruct} = {
                "nftId": fishNFTId,
                "speciesCode": speciesCode
            }
            
            // Call the species coin contract to redeem
            let vault <- redeemer.redeemCatch(fishData: fishData, angler: angler)
            
            // Get the recipient's vault capability
            let recipientAccount = getAccount(angler)
            if let recipientVault = recipientAccount.capabilities
                .borrow<&{FungibleToken.Receiver}>(self.VaultReceiverPath) {
                // Deposit the redeemed coins
                recipientVault.deposit(from: <-vault)
            } else {
                // If recipient doesn't have a vault set up, destroy the tokens
                destroy vault
                panic("Recipient does not have a vault set up")
            }
        } else {
            panic("Could not borrow SpeciesCoinRedeemer capability")
        }
    }

    // ADDITIONAL UTILITY FUNCTIONS
    access(all) fun getUnredeemedNFTs(nftIds: [UInt64]): [UInt64] {
        let unredeemed: [UInt64] = []
        for nftId in nftIds {
            if !self.hasBeenRedeemedForCoin(fishNFTId: nftId) {
                unredeemed.append(nftId)
            }
        }
        return unredeemed
    }

    access(all) fun getRedemptionStatus(nftIds: [UInt64]): {UInt64: Bool} {
        let status: {UInt64: Bool} = {}
        for nftId in nftIds {
            status[nftId] = self.hasBeenRedeemedForCoin(fishNFTId: nftId)
        }
        return status
    }

    // ADMIN FUNCTION - Reset redemption status (use with caution!)
    access(all) fun resetRedemptionStatus(fishNFTId: UInt64) {
        self.speciesCoinsRedeemed.remove(key: fishNFTId)
        log("Reset redemption status for Fish NFT #".concat(fishNFTId.toString()))
    }

    init() {
        self.CollectionStoragePath = /storage/FishNFTCollection
        self.CollectionPublicPath = /public/FishNFTCollection
        self.MinterStoragePath = /storage/FishNFTMinter
        self.SpeciesCoinRedeemerPath = /public/SpeciesCoinRedeemer
        self.VaultReceiverPath = /public/GenericFungibleTokenReceiver

        // Initialize species integration variables
        self.speciesRegistry = {}
        self.totalFishCaught = 0
        self.speciesCoinsRedeemed = {}

        let collection <- create Collection()
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)

        let collectionCap = self.account.capabilities.storage.issue<&FishNFT.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(collectionCap, at: self.CollectionPublicPath)

        let minter <- create NFTMinter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
    }
} 