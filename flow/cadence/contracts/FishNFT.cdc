import "NonFungibleToken"
import "MetadataViews"
import "Xorshift128plus"

access(all) contract FishNFT: NonFungibleToken {

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

    // Storage paths
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    
    // FishCard storage paths
    access(all) let FishCardCollectionStoragePath: StoragePath
    access(all) let FishCardCollectionPublicPath: PublicPath
    access(all) let FishCardMinterStoragePath: StoragePath

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

    // FishCard events
    access(all) event FishCardMinted(
        id: UInt64,
        fishNFTId: UInt64,
        recipient: Address,
        species: String,
        revealedFields: [String]
    )

    access(all) event FishCardCommitted(
        commitId: UInt64,
        fishNFTId: UInt64,
        committer: Address,
        commitBlock: UInt64,
        revealBlock: UInt64
    )

    access(all) event FishCardRevealed(
        commitId: UInt64,
        fishCardId: UInt64,
        revealedFields: [String]
    )

    // FishCard state
    access(all) var totalFishCards: UInt64
    access(all) var nextCommitId: UInt64

    // Active commits for commit-reveal scheme
    access(self) var activeCommits: {UInt64: FishCardCommit}

    // FishCard Receipt storage path
    access(all) let FishCardReceiptStoragePath: StoragePath

    // Simple commit structure
    access(all) struct FishCardCommit {
        access(all) let id: UInt64
        access(all) let fishNFTId: UInt64
        access(all) let fishNFTOwner: Address
        access(all) let recipient: Address
        access(all) let commitBlock: UInt64
        access(all) let userSalt: [UInt8]

        init(id: UInt64, fishNFTId: UInt64, fishNFTOwner: Address, recipient: Address, userSalt: [UInt8]) {
            self.id = id
            self.fishNFTId = fishNFTId
            self.fishNFTOwner = fishNFTOwner
            self.recipient = recipient
            self.commitBlock = getCurrentBlock().height
            self.userSalt = userSalt
        }
    }

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

            // LOCATION & ENVIRONMENTAL DATA
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

            // MEDIA
            bumpShotUrl: String,
            heroShotUrl: String,
            bumpHash: String,
            heroHash: String,
            releaseVideoUrl: String?,
            releaseHash: String?,

            // ANGLER DATA
            location: String?,
            waterClarity: String?,
            currentStrength: String?,
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
            self.owner = owner
            self.species = species
            self.scientific = scientific
            self.length = length
            self.weight = weight
            self.timestamp = timestamp
            self.speciesCode = speciesCode
            self.hasRelease = hasRelease
            self.allowFishCards = false  // Disabled by default

            // Competition data
            self.competitions = competitions
            self.prizesWon = prizesWon
            self.totalPrizeValue = totalPrizeValue

            // Verification data
            self.verificationLevel = verificationLevel
            self.verifiedBy = verifiedBy
            self.verifiedAt = verifiedAt
            self.competitionId = competitionId
            self.recordStatus = recordStatus
            self.certificationLevel = certificationLevel
            self.qualityScore = qualityScore

            // Location data
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

            // Media
            self.bumpShotUrl = bumpShotUrl
            self.heroShotUrl = heroShotUrl
            self.bumpHash = bumpHash
            self.heroHash = heroHash
            self.releaseVideoUrl = releaseVideoUrl
            self.releaseHash = releaseHash

            // Angler data
            self.location = location
            self.waterClarity = waterClarity
            self.currentStrength = currentStrength
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

    // FishCard metadata structure - contains selectively revealed data from Fish NFT
    access(all) struct FishCardMetadata {
        // CORE FIELDS - Always included from original Fish NFT
        access(all) let fishNFTId: UInt64
        access(all) let originalOwner: Address
        access(all) let species: String
        access(all) let scientific: String
        access(all) let length: UFix64
        access(all) let timestamp: UFix64
        access(all) let speciesCode: String
        access(all) let hasRelease: Bool
        
        // SELECTIVELY REVEALED FIELDS - Based on VRF coin flips
        access(all) let weight: UFix64?
        access(all) let qualityScore: UFix64?
        access(all) let waterBody: String?
        access(all) let verificationLevel: String?
        access(all) let bumpShotUrl: String?
        access(all) let heroShotUrl: String?
        
        // REVEALED LOCATION DATA - Based on coin flips
        access(all) let longitude: Fix64?
        access(all) let latitude: Fix64?
        access(all) let waterTemp: UFix64?
        access(all) let airTemp: UFix64?
        access(all) let weather: String?
        access(all) let moonPhase: String?
        access(all) let tide: String?
        
        // REVEALED ANGLER DATA - Based on coin flips  
        access(all) let location: String?
        access(all) let gear: String?
        access(all) let baitLure: String?
        access(all) let technique: String?
        access(all) let girth: UFix64?
        access(all) let fightDuration: UFix64?
        
        // METADATA
        access(all) let revealedFields: [String]
        access(all) let cardRarity: String  // Based on number of revealed fields
        
        init(
            fishNFTId: UInt64,
            originalOwner: Address,
            species: String,
            scientific: String,
            length: UFix64,
            timestamp: UFix64,
            speciesCode: String,
            hasRelease: Bool,
            weight: UFix64?,
            qualityScore: UFix64?,
            waterBody: String?,
            verificationLevel: String?,
            bumpShotUrl: String?,
            heroShotUrl: String?,
            longitude: Fix64?,
            latitude: Fix64?,
            waterTemp: UFix64?,
            airTemp: UFix64?,
            weather: String?,
            moonPhase: String?,
            tide: String?,
            location: String?,
            gear: String?,
            baitLure: String?,
            technique: String?,
            girth: UFix64?,
            fightDuration: UFix64?,
            revealedFields: [String]
        ) {
            self.fishNFTId = fishNFTId
            self.originalOwner = originalOwner
            self.species = species
            self.scientific = scientific
            self.length = length
            self.timestamp = timestamp
            self.speciesCode = speciesCode
            self.hasRelease = hasRelease
            self.weight = weight
            self.qualityScore = qualityScore
            self.waterBody = waterBody
            self.verificationLevel = verificationLevel
            self.bumpShotUrl = bumpShotUrl
            self.heroShotUrl = heroShotUrl
            self.longitude = longitude
            self.latitude = latitude
            self.waterTemp = waterTemp
            self.airTemp = airTemp
            self.weather = weather
            self.moonPhase = moonPhase
            self.tide = tide
            self.location = location
            self.gear = gear
            self.baitLure = baitLure
            self.technique = technique
            self.girth = girth
            self.fightDuration = fightDuration
            self.revealedFields = revealedFields
            
            // Calculate rarity based on revealed fields
            let revealCount = revealedFields.length
            if revealCount <= 3 {
                self.cardRarity = "Common"
            } else if revealCount <= 6 {
                self.cardRarity = "Uncommon"
            } else if revealCount <= 9 {
                self.cardRarity = "Rare"
            } else if revealCount <= 12 {
                self.cardRarity = "Epic"
            } else {
                self.cardRarity = "Legendary"
            }
        }
    }

    access(all) resource NFT: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) let metadata: FishMetadata
        access(all) let mintedBy: Address

        // Convenience accessors for common fields
        access(all) view fun getSpecies(): String {
            return self.metadata.species
        }

        access(all) view fun getSpeciesCode(): String {
            return self.metadata.speciesCode
        }

        access(all) view fun getLength(): UFix64 {
            return self.metadata.length
        }

        access(all) view fun getWeight(): UFix64? {
            return self.metadata.weight
        }

        access(all) view fun getTimestamp(): UFix64 {
            return self.metadata.timestamp
        }

        access(all) view fun getHasRelease(): Bool {
            return self.metadata.hasRelease
        }

        access(all) view fun getOwner(): Address {
            return self.metadata.owner
        }

        // Access private data (only for owner or admin)
        access(all) fun getPrivateData(caller: Address): {String: AnyStruct}? {
            return self.metadata.getPrivateData(caller: caller)
        }

        // Enable fish card minting
        access(all) fun enableFishCards() {
            self.metadata.enableFishCards()
        }

        access(all) view fun canMintFishCards(): Bool {
            return self.metadata.allowFishCards
        }

        // Views implementation
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.metadata.species.concat(" - ").concat(self.metadata.length.toString()).concat("\""),
                        description: "A verified ".concat(self.metadata.species).concat(" catch from DerbyFish"),
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.metadata.heroShotUrl
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties([])
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://derby.fish/catch/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: FishNFT.CollectionStoragePath,
                        publicPath: FishNFT.CollectionPublicPath,
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
                case Type<MetadataViews.Traits>():
                    return MetadataViews.Traits([
                        MetadataViews.Trait(name: "species", value: self.metadata.species, displayType: nil, rarity: nil),
                        MetadataViews.Trait(name: "scientific", value: self.metadata.scientific, displayType: nil, rarity: nil),
                        MetadataViews.Trait(name: "length", value: self.metadata.length, displayType: "Number", rarity: nil),
                        MetadataViews.Trait(name: "hasRelease", value: self.metadata.hasRelease, displayType: nil, rarity: nil),
                        MetadataViews.Trait(name: "speciesCode", value: self.metadata.speciesCode, displayType: nil, rarity: nil)
                    ])
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-create Collection()
        }

        init(id: UInt64, metadata: FishMetadata, mintedBy: Address) {
            self.id = id
            self.metadata = metadata
            self.mintedBy = mintedBy
        }
    }

    // FishCard NFT Resource
    access(all) resource FishCard: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) let metadata: FishCardMetadata
        access(all) let mintedBy: Address
        access(all) let mintedAt: UFix64

        // Convenience accessors
        access(all) view fun getSpecies(): String {
            return self.metadata.species
        }

        access(all) view fun getFishNFTId(): UInt64 {
            return self.metadata.fishNFTId
        }

        access(all) view fun getRarity(): String {
            return self.metadata.cardRarity
        }

        access(all) view fun getRevealedFields(): [String] {
            return self.metadata.revealedFields
        }

        // Views implementation for FishCard
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.metadata.species.concat(" Card #").concat(self.id.toString()),
                        description: "A trading card featuring a ".concat(self.metadata.species).concat(" catch - ").concat(self.metadata.cardRarity).concat(" rarity"),
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.metadata.heroShotUrl ?? "https://derby.fish/images/card-placeholder.png"
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
                case Type<MetadataViews.Traits>():
                    let traits: [MetadataViews.Trait] = []
                    traits.append(MetadataViews.Trait(name: "species", value: self.metadata.species, displayType: nil, rarity: nil))
                    traits.append(MetadataViews.Trait(name: "rarity", value: self.metadata.cardRarity, displayType: nil, rarity: nil))
                    traits.append(MetadataViews.Trait(name: "revealedFields", value: self.metadata.revealedFields.length, displayType: "Number", rarity: nil))
                    traits.append(MetadataViews.Trait(name: "fishNFTId", value: self.metadata.fishNFTId, displayType: "Number", rarity: nil))
                    return MetadataViews.Traits(traits)
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-create FishCardCollection()
        }

        init(id: UInt64, metadata: FishCardMetadata, mintedBy: Address) {
            self.id = id
            self.metadata = metadata
            self.mintedBy = mintedBy
            self.mintedAt = getCurrentBlock().timestamp
        }
    }

    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        access(all) view fun getLength(): Int {
            return self.ownedNFTs.length
        }

        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        access(all) fun borrowEntireNFT(id: UInt64): &FishNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
                return ref as! &FishNFT.NFT
            }
            return nil
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @FishNFT.NFT
            let id = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            destroy oldToken
        }

        // Override withdraw to prevent transfers
        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            panic("FishNFTs are non-transferable")
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@FishNFT.NFT>()] = true
            return supportedTypes
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@FishNFT.NFT>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-create Collection()
        }

        init() {
            self.ownedNFTs <- {}
        }
    }

    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    // FishCard Collection Resource - Remains transferable
    access(all) resource FishCardCollection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        access(all) view fun getLength(): Int {
            return self.ownedNFTs.length
        }

        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        access(all) fun borrowFishCard(id: UInt64): &FishNFT.FishCard? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
                return ref as! &FishNFT.FishCard
            }
            return nil
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @FishNFT.FishCard
            let id = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            destroy oldToken
        }

        // Keep withdraw enabled for FishCards
        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("Could not withdraw a FishCard with the specified ID")
            return <-token
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@FishNFT.FishCard>()] = true
            return supportedTypes
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@FishNFT.FishCard>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-create FishCardCollection()
        }

        init() {
            self.ownedNFTs <- {}
        }
    }

    access(all) fun createEmptyFishCardCollection(): @{NonFungibleToken.Collection} {
        return <- create FishCardCollection()
    }

    // Simple FishCard Receipt for commit-reveal scheme
    access(all) resource FishCardReceipt {
        access(all) let commitId: UInt64

        init(commitId: UInt64) {
            self.commitId = commitId
        }
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

            self.nextID = self.nextID + 1

            return <-newNFT
        }
        
        // Enhanced mint function with species validation
        access(all) fun mintNFTWithSpeciesValidation(
            // REQUIRED CORE DATA
            recipient: Address,
            species: String,
            scientific: String,
            length: UFix64,
            weight: UFix64?,
            timestamp: UFix64,
            speciesCode: String,
            hasRelease: Bool,
            
            // REQUIRED MEDIA
            bumpShotUrl: String,
            heroShotUrl: String,
            bumpHash: String,
            heroHash: String,
            releaseVideoUrl: String?,
            releaseHash: String?,
            
            // LOCATION DATA
            longitude: Fix64,
            latitude: Fix64,
            waterBody: String?,
            
            // OPTIONAL ENVIRONMENTAL DATA
            waterTemp: UFix64?,
            airTemp: UFix64?,
            weather: String?,
            moonPhase: String?,
            tide: String?,
            barometricPressure: UFix64?,
            windSpeed: UFix64?,
            windDirection: String?,
            skyConditions: String?,
            waterDepth: UFix64?,
            structureType: String?,
            bottomType: String?,
            
            // OPTIONAL ANGLER DATA
            location: String?,
            waterClarity: String?,
            currentStrength: String?,
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
        ): @FishNFT.NFT {
            
            // Create metadata with all provided fields
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
                waterTemp: waterTemp,
                airTemp: airTemp,
                weather: weather,
                moonPhase: moonPhase,
                tide: tide,
                waterBody: waterBody,
                barometricPressure: barometricPressure,
                windSpeed: windSpeed,
                windDirection: windDirection,
                skyConditions: skyConditions,
                waterDepth: waterDepth,
                structureType: structureType,
                bottomType: bottomType,

                // MEDIA
                bumpShotUrl: bumpShotUrl,
                heroShotUrl: heroShotUrl,
                bumpHash: bumpHash,
                heroHash: heroHash,
                releaseVideoUrl: releaseVideoUrl,
                releaseHash: releaseHash,

                // ANGLER DATA
                location: location,
                waterClarity: waterClarity,
                currentStrength: currentStrength,
                gear: gear,
                baitLure: baitLure,
                fightDuration: fightDuration,
                technique: technique,
                girth: girth,
                rodType: rodType,
                reelType: reelType,
                lineType: lineType,
                leaderType: leaderType,
                hookType: hookType,
                presentation: presentation,
                retrieveSpeed: retrieveSpeed,
                catchDepth: catchDepth
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

    // FishCard Minter Resource with RandomConsumer commit-reveal pattern
    access(all) resource FishCardMinter {
        access(all) var nextCardID: UInt64

        init() {
            self.nextCardID = 1
        }

        // COMMIT PHASE: Create receipt for future FishCard minting
        access(all) fun commitFishCard(
            fishNFTId: UInt64,
            fishNFTOwner: Address,
            recipient: Address,
            userSalt: [UInt8]
        ): @FishCardReceipt {
            // Verify Fish NFT exists and can mint cards
            let ownerAccount = getAccount(fishNFTOwner)
            let collectionRef = ownerAccount.capabilities.borrow<&FishNFT.Collection>(FishNFT.CollectionPublicPath)
                ?? panic("Could not borrow Fish NFT collection from owner")
            
            let fishNFT = collectionRef.borrowEntireNFT(id: fishNFTId)
                ?? panic("Could not borrow Fish NFT with ID: ".concat(fishNFTId.toString()))

            assert(fishNFT.canMintFishCards(), message: "FishCard minting not enabled for this Fish NFT")

            // Create commit
            let commitId = FishNFT.nextCommitId
            let commit = FishCardCommit(
                id: commitId,
                fishNFTId: fishNFTId,
                fishNFTOwner: fishNFTOwner,
                recipient: recipient,
                userSalt: userSalt
            )

            // Store the commit
            FishNFT.activeCommits[commitId] = commit
            FishNFT.nextCommitId = FishNFT.nextCommitId + 1

            // Create and return receipt
            let receipt <- create FishCardReceipt(commitId: commitId)

            emit FishCardCommitted(
                commitId: commitId,
                fishNFTId: fishNFTId,
                committer: recipient,
                commitBlock: commit.commitBlock,
                revealBlock: commit.commitBlock + 1
            )

            return <-receipt
        }

        // REVEAL PHASE: Use committed randomness to mint FishCard
        access(all) fun revealFishCard(receipt: @FishCardReceipt): @FishNFT.FishCard {
            // Get commit data
            let commit = FishNFT.activeCommits[receipt.commitId]
                ?? panic("Commit not found")

            assert(getCurrentBlock().height > commit.commitBlock, message: "Must wait at least 1 block to reveal")

            // Get Fish NFT
            let ownerAccount = getAccount(commit.fishNFTOwner)
            let collectionRef = ownerAccount.capabilities.borrow<&FishNFT.Collection>(FishNFT.CollectionPublicPath)
                ?? panic("Could not borrow Fish NFT collection from owner")
            
            let fishNFT = collectionRef.borrowEntireNFT(id: commit.fishNFTId)
                ?? panic("Could not borrow Fish NFT")

            // Get private data from Fish NFT
            let privateData = fishNFT.getPrivateData(caller: FishNFT.account.address)
            let fishMetadata = fishNFT.metadata

            // Create randomness source using current block + user salt
            let blockHash = getCurrentBlock().id
            var blockHashArray: [UInt8] = []
            var i = 0
            while i < blockHash.length {
                blockHashArray.append(blockHash[i])
                i = i + 1
            }
            let randomSource = commit.userSalt.concat(blockHashArray)
            var prg = Xorshift128plus.PRG(sourceOfRandomness: randomSource, salt: commit.fishNFTId.toBigEndianBytes())
            
            // Perform coin flips for each non-core field using PRG
            let revealedFields: [String] = []
            
            // Non-core fields to coin flip
            let weight = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) ? fishMetadata.weight : nil
            if weight != nil { revealedFields.append("weight") }
            
            let qualityScore = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) ? fishMetadata.qualityScore : nil
            if qualityScore != nil { revealedFields.append("qualityScore") }
            
            let waterBody = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) ? fishMetadata.waterBody : nil
            if waterBody != nil { revealedFields.append("waterBody") }
            
            let verificationLevel = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) ? fishMetadata.verificationLevel : nil
            if verificationLevel != nil { revealedFields.append("verificationLevel") }
            
            let bumpShotUrl = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) ? fishMetadata.bumpShotUrl : nil
            if bumpShotUrl != nil { revealedFields.append("bumpShotUrl") }
            
            let heroShotUrl = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) ? fishMetadata.heroShotUrl : nil
            if heroShotUrl != nil { revealedFields.append("heroShotUrl") }

            // Private location data coin flips
            let longitude = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["longitude"] as! Fix64?) : nil
            if longitude != nil { revealedFields.append("longitude") }
            
            let latitude = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["latitude"] as! Fix64?) : nil
            if latitude != nil { revealedFields.append("latitude") }
            
            let waterTemp = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["waterTemp"] as! UFix64?) : nil
            if waterTemp != nil { revealedFields.append("waterTemp") }
            
            let airTemp = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["airTemp"] as! UFix64?) : nil
            if airTemp != nil { revealedFields.append("airTemp") }
            
            let weather = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["weather"] as! String?) : nil
            if weather != nil { revealedFields.append("weather") }
            
            let moonPhase = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["moonPhase"] as! String?) : nil
            if moonPhase != nil { revealedFields.append("moonPhase") }
            
            let tide = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["tide"] as! String?) : nil
            if tide != nil { revealedFields.append("tide") }

            // Private angler data coin flips
            let location = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["location"] as! String?) : nil
            if location != nil { revealedFields.append("location") }
            
            let gear = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["gear"] as! String?) : nil
            if gear != nil { revealedFields.append("gear") }
            
            let baitLure = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["baitLure"] as! String?) : nil
            if baitLure != nil { revealedFields.append("baitLure") }
            
            let technique = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["technique"] as! String?) : nil
            if technique != nil { revealedFields.append("technique") }
            
            let girth = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["girth"] as! UFix64?) : nil
            if girth != nil { revealedFields.append("girth") }
            
            let fightDuration = self.coinFlip(prg: &prg as &Xorshift128plus.PRG) && privateData != nil ? (privateData!["fightDuration"] as! UFix64?) : nil
            if fightDuration != nil { revealedFields.append("fightDuration") }

            // Create FishCard metadata
            let cardMetadata = FishCardMetadata(
                fishNFTId: fishNFT.id,
                originalOwner: fishMetadata.owner,
                species: fishMetadata.species,
                scientific: fishMetadata.scientific,
                length: fishMetadata.length,
                timestamp: fishMetadata.timestamp,
                speciesCode: fishMetadata.speciesCode,
                hasRelease: fishMetadata.hasRelease,
                weight: weight,
                qualityScore: qualityScore,
                waterBody: waterBody,
                verificationLevel: verificationLevel,
                bumpShotUrl: bumpShotUrl,
                heroShotUrl: heroShotUrl,
                longitude: longitude,
                latitude: latitude,
                waterTemp: waterTemp,
                airTemp: airTemp,
                weather: weather,
                moonPhase: moonPhase,
                tide: tide,
                location: location,
                gear: gear,
                baitLure: baitLure,
                technique: technique,
                girth: girth,
                fightDuration: fightDuration,
                revealedFields: revealedFields
            )

            // Create and return the FishCard
            let newFishCard <- create FishCard(
                id: self.nextCardID,
                metadata: cardMetadata,
                mintedBy: FishNFT.account.address
            )

            emit FishCardMinted(
                id: self.nextCardID,
                fishNFTId: fishNFT.id,
                recipient: commit.recipient,
                species: fishMetadata.species,
                revealedFields: revealedFields
            )

            emit FishCardRevealed(
                commitId: receipt.commitId,
                fishCardId: self.nextCardID,
                revealedFields: revealedFields
            )

            // Update counts and cleanup
            FishNFT.totalFishCards = FishNFT.totalFishCards + 1
            self.nextCardID = self.nextCardID + 1
            FishNFT.activeCommits.remove(key: receipt.commitId)

            // Clean up receipt
            destroy receipt

            return <-newFishCard
        }

        // Simple coin flip using PRG
        access(contract) fun coinFlip(prg: &Xorshift128plus.PRG): Bool {
            let randomValue = prg.nextUInt64()
            return randomValue % 2 == 0
        }
    }

    // Public query functions
    access(all) view fun getTotalFishCaught(): UInt64 {
        return self.totalFishCaught
    }

    access(all) view fun getTotalFishCards(): UInt64 {
        return self.totalFishCards
    }

    // Public FishCard commit function - anyone can call to start the process
    access(all) fun commitFishCard(
        fishNFTId: UInt64,
        fishNFTOwner: Address,
        recipient: Address,
        userSalt: [UInt8]
    ): @FishCardReceipt {
        // Get minter reference
        let minterRef = self.account.storage.borrow<&FishCardMinter>(from: self.FishCardMinterStoragePath)
            ?? panic("Could not borrow FishCard minter")

        // Commit the card request
        return <- minterRef.commitFishCard(
            fishNFTId: fishNFTId,
            fishNFTOwner: fishNFTOwner,
            recipient: recipient,
            userSalt: userSalt
        )
    }

    // Public FishCard reveal function - reveals the card from a receipt
    access(all) fun revealFishCard(receipt: @FishCardReceipt): @FishNFT.FishCard {
        // Get minter reference
        let minterRef = self.account.storage.borrow<&FishCardMinter>(from: self.FishCardMinterStoragePath)
            ?? panic("Could not borrow FishCard minter")

        // Reveal the card
        return <- minterRef.revealFishCard(receipt: <-receipt)
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

    init() {
        self.CollectionStoragePath = /storage/FishNFTCollection
        self.CollectionPublicPath = /public/FishNFTCollection
        self.MinterStoragePath = /storage/FishNFTMinter

        // Initialize FishCard storage paths
        self.FishCardCollectionStoragePath = /storage/FishCardCollection
        self.FishCardCollectionPublicPath = /public/FishCardCollection
        self.FishCardMinterStoragePath = /storage/FishCardMinter

        // Initialize species integration variables
        self.speciesRegistry = {}
        self.totalFishCaught = 0
        self.totalFishCards = 0
        self.nextCommitId = 0
        self.activeCommits = {}

        // Set FishCard Receipt storage path
        self.FishCardReceiptStoragePath = StoragePath(identifier: "FishCardReceipt_".concat(self.account.address.toString()))!

        // Create Fish NFT collection and minter
        let collection <- create Collection()
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)

        let collectionCap = self.account.capabilities.storage.issue<&FishNFT.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(collectionCap, at: self.CollectionPublicPath)

        let minter <- create NFTMinter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)

        // Create FishCard collection and minter
        let fishCardCollection <- create FishCardCollection()
        self.account.storage.save(<-fishCardCollection, to: self.FishCardCollectionStoragePath)

        let fishCardCollectionCap = self.account.capabilities.storage.issue<&FishNFT.FishCardCollection>(self.FishCardCollectionStoragePath)
        self.account.capabilities.publish(fishCardCollectionCap, at: self.FishCardCollectionPublicPath)

        let fishCardMinter <- create FishCardMinter()
        self.account.storage.save(<-fishCardMinter, to: self.FishCardMinterStoragePath)
    }
} 