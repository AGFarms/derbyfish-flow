import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"

access(all) contract FishCardV1: NonFungibleToken, ViewResolver.Resolver {

    // Contract metadata
    access(all) let name: String
    access(all) let symbol: String
    access(all) let description: String
    access(all) let externalURL: String
    access(all) let imageURL: String
    access(all) let socials: {String: String}

    // Total supply tracking
    access(all) var totalSupply: UInt64

    // Storage paths
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let AdminStoragePath: StoragePath

    // Events
    access(all) event ContractInitialized()
    access(all) event FishCardMinted(id: UInt64, owner: Address, species: String, length: UFix64)
    access(all) event FishCardBurned(id: UInt64, owner: Address)
    access(all) event FishCardTransferred(id: UInt64, from: Address, to: Address)
    access(all) event MediaStored(id: UInt64, storagePath: String, storageSizeBytes: UInt64, requiredFlowStake: UFix64)

    // Submission standards
    access(all) enum SubmissionStandard: UInt8 {
        access(all) case BHRV  // Bump, Hero, Release
        access(all) case FISHSCAN  // Livestream with 3D gyro scan
        access(all) case BANANNASCAN  // a form of test scan we have with bananna
    }

    // Media item structure for Flow decentralized storage
    access(all) struct MediaItem {
        access(all) let mime: String
        access(all) let flowStoragePath: String  // Flow decentralized storage path
        access(all) let hash: String
        access(all) let algorithm: String
        access(all) let storageSizeBytes: UInt64  // Size of media in bytes
        access(all) let requiredFlowStake: UFix64  // FLOW tokens required to stake (0.01 FLOW per MB)
        access(all) let uploadedAt: UFix64  // Upload timestamp

        init(mime: String, flowStoragePath: String, hash: String, algorithm: String, storageSizeBytes: UInt64) {
            self.mime = mime
            self.flowStoragePath = flowStoragePath
            self.hash = hash
            self.algorithm = algorithm
            self.storageSizeBytes = storageSizeBytes
            // Calculate required FLOW stake: 0.01 FLOW per MB (1,048,576 bytes)
            self.requiredFlowStake = UFix64(storageSizeBytes) / 1048576.0 * 0.01
            self.uploadedAt = getCurrentBlock().timestamp
        }
    }

    // Verification data structure
    access(all) struct Verification {
        access(all) let verifier: String
        access(all) let timestamp: UFix64
        access(all) let method: String
        access(all) let confidence: UFix64
        access(all) let metadata: String

        init(verifier: String, timestamp: UFix64, method: String, confidence: UFix64, metadata: String) {
            self.verifier = verifier
            self.timestamp = timestamp
            self.method = method
            self.confidence = confidence
            self.metadata = metadata
        }
    }

    // Public data structure (visible to all)
    access(all) struct PublicData {
        access(all) let dateOfCatch: UFix64
        access(all) let species: String
        access(all) let length: UFix64
        access(all) let angler: String
        access(all) let pricePerCard: UFix64
        access(all) let cardTotalSupply: UInt64
        access(all) let hasPhysicalFishRights: Bool
        access(all) let released: Bool
        access(all) let catchReel: String

        init(
            dateOfCatch: UFix64,
            species: String,
            length: UFix64,
            angler: String,
            pricePerCard: UFix64,
            cardTotalSupply: UInt64,
            hasPhysicalFishRights: Bool,
            released: Bool,
            catchReel: String
        ) {
            self.dateOfCatch = dateOfCatch
            self.species = species
            self.length = length
            self.angler = angler
            self.pricePerCard = pricePerCard
            self.cardTotalSupply = cardTotalSupply
            self.hasPhysicalFishRights = hasPhysicalFishRights
            self.released = released
            self.catchReel = catchReel
        }
    }

    // Private data structure (only visible to owner)
    access(all) struct PrivateData {
        access(all) let geoCoords: String
        access(all) let exactTimestamp: UFix64
        access(all) let weatherConditions: String
        access(all) let anglerAddedData: String
        access(all) let aiAnalyzedData: String
        access(all) let scalePatternHash: String

        init(
            geoCoords: String,
            exactTimestamp: UFix64,
            weatherConditions: String,
            anglerAddedData: String,
            aiAnalyzedData: String,
            scalePatternHash: String
        ) {
            self.geoCoords = geoCoords
            self.exactTimestamp = exactTimestamp
            self.weatherConditions = weatherConditions
            self.anglerAddedData = anglerAddedData
            self.aiAnalyzedData = aiAnalyzedData
            self.scalePatternHash = scalePatternHash
        }
    }


    ///
    /// NFT BASE TEMPLATE STUFF BELOW
    /// 

    // Main FishCard NFT resource
    access(all) resource NFT: NonFungibleToken.INFT, ViewResolver.Resolver {
        access(all) let id: UInt64
        access(all) let submissionStandard: SubmissionStandard
        access(all) let mediaArray: [MediaItem]
        access(all) let species: String
        access(all) let length: UFix64
        access(all) let publicData: PublicData
        access(all) let privateData: PrivateData
        access(all) let verified: Verification
        access(all) let mintedAt: UFix64
        access(all) let mintedBy: Address

        init(
            id: UInt64,
            submissionStandard: SubmissionStandard,
            mediaArray: [MediaItem],
            species: String,
            length: UFix64,
            publicData: PublicData,
            privateData: PrivateData,
            verified: Verification,
            mintedBy: Address
        ) {
            self.id = id
            self.submissionStandard = submissionStandard
            self.mediaArray = mediaArray
            self.species = species
            self.length = length
            self.publicData = publicData
            self.privateData = privateData
            self.verified = verified
            self.mintedAt = getCurrentBlock().timestamp
            self.mintedBy = mintedBy
        }

        // ViewResolver implementation for metadata
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Royalties>()
            ]
        }

        access(all) view fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "Fish Card #".concat(self.id.toString()),
                        description: "A digital catch NFT representing a ".concat(self.species).concat(" caught on ").concat(self.publicData.dateOfCatch.toString()),
                        thumbnail: MetadataViews.Media(
                            file: self.mediaArray.length > 0 ? MetadataViews.IPFSFile(url: self.mediaArray[0].flowStoragePath) : MetadataViews.HTTPFile(url: FishCardV1.imageURL),
                            mediaType: self.mediaArray.length > 0 ? self.mediaArray[0].mime : "image/png"
                        ),
                        externalURL: MetadataViews.ExternalURL(FishCardV1.externalURL),
                        socials: FishCardV1.socials,
                        media: self.getMediaViews(),
                        attributes: self.getAttributes()
                    )
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: FishCardV1.CollectionStoragePath,
                        publicPath: FishCardV1.CollectionPublicPath,
                        providerPath: /private/fishCardCollectionProvider,
                        publicCollection: Type<&FishCardV1.Collection{NonFungibleToken.CollectionPublic}>(),
                        storageType: Type<@FishCardV1.Collection>(),
                        publicLinkedType: Type<&FishCardV1.Collection{NonFungibleToken.CollectionPublic}>(),
                        privateLinkedType: Type<&FishCardV1.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.CollectionPrivate}>(),
                        publicCollectionCapability: Type<Capability<&FishCardV1.Collection{NonFungibleToken.CollectionPublic}>>(),
                        createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                            return <-FishCardV1.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return MetadataViews.NFTCollectionDisplay(
                        name: FishCardV1.name,
                        description: FishCardV1.description,
                        externalURL: MetadataViews.ExternalURL(FishCardV1.externalURL),
                        squareImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: FishCardV1.imageURL),
                            mediaType: "image/png"
                        ),
                        bannerImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: FishCardV1.imageURL),
                            mediaType: "image/png"
                        ),
                        socials: FishCardV1.socials
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        cutInfos: [],
                        description: "No royalties configured"
                    )
            }
            return nil
        }

        // Helper function to get media views
        access(all) view fun getMediaViews(): [MetadataViews.Media] {
            let medias: [MetadataViews.Media] = []
            for mediaItem in self.mediaArray {
                medias.append(
                    MetadataViews.Media(
                        file: MetadataViews.IPFSFile(url: mediaItem.flowStoragePath),
                        mediaType: mediaItem.mime
                    )
                )
            }
            return medias
        }

        // Helper function to get attributes
        access(all) view fun getAttributes(): [MetadataViews.Attribute] {
            return [
                MetadataViews.Attribute(
                    name: "Species",
                    value: MetadataViews.StringValue(self.species)
                ),
                MetadataViews.Attribute(
                    name: "Length",
                    value: MetadataViews.StringValue(self.length.toString().concat(" cm"))
                ),
                MetadataViews.Attribute(
                    name: "Submission Standard",
                    value: MetadataViews.StringValue(self.submissionStandard.toString())
                ),
                MetadataViews.Attribute(
                    name: "Date of Catch",
                    value: MetadataViews.StringValue(self.publicData.dateOfCatch.toString())
                ),
                MetadataViews.Attribute(
                    name: "Angler",
                    value: MetadataViews.StringValue(self.publicData.angler)
                ),
                MetadataViews.Attribute(
                    name: "Released",
                    value: MetadataViews.BoolValue(self.publicData.released)
                ),
                MetadataViews.Attribute(
                    name: "Physical Fish Rights",
                    value: MetadataViews.BoolValue(self.publicData.hasPhysicalFishRights)
                ),
                MetadataViews.Attribute(
                    name: "Verification Method",
                    value: MetadataViews.StringValue(self.verified.method)
                ),
                MetadataViews.Attribute(
                    name: "Verification Confidence",
                    value: MetadataViews.StringValue(self.verified.confidence.toString())
                ),
                MetadataViews.Attribute(
                    name: "Total FLOW Stake Required",
                    value: MetadataViews.StringValue(self.getTotalRequiredFlowStake().toString().concat(" FLOW"))
                ),
                MetadataViews.Attribute(
                    name: "Total Storage Size",
                    value: MetadataViews.StringValue(self.getTotalStorageSize().toString().concat(" bytes"))
                ),
                MetadataViews.Attribute(
                    name: "Media Count",
                    value: MetadataViews.UInt64Value(self.mediaArray.length)
                )
            ]
        }

        // Function to get private data (only accessible by owner)
        access(all) fun getPrivateData(): PrivateData {
            return self.privateData
        }

        // Function to check media storage status
        access(all) view fun getMediaStorageStatus(): [String] {
            let statuses: [String] = []
            
            for mediaItem in self.mediaArray {
                let sizeMB = UFix64(mediaItem.storageSizeBytes) / 1048576.0
                statuses.append("Size: ".concat(sizeMB.toString()).concat(" MB, Required Stake: ").concat(mediaItem.requiredFlowStake.toString()).concat(" FLOW"))
            }
            return statuses
        }

        // Function to get total FLOW stake required for all media
        access(all) view fun getTotalRequiredFlowStake(): UFix64 {
            var totalStake: UFix64 = 0.0
            for mediaItem in self.mediaArray {
                totalStake = totalStake + mediaItem.requiredFlowStake
            }
            return totalStake
        }

        // Function to get total storage size in bytes
        access(all) view fun getTotalStorageSize(): UInt64 {
            var totalSize: UInt64 = 0
            for mediaItem in self.mediaArray {
                totalSize = totalSize + mediaItem.storageSizeBytes
            }
            return totalSize
        }
    }

    // Collection resource for managing NFTs
    access(all) resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, NonFungibleToken.CollectionPrivate {
        access(all) var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        access(all) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let nft <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("NFT not found in collection")
            
            emit FishCardTransferred(id: withdrawID, from: self.owner?.address ?? panic("Collection has no owner"), to: 0x0)
            return <-nft
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let nft <- token as! @FishCardV1.NFT
            let id = nft.id
            let oldNFT <- self.ownedNFTs[id] <- nft
            destroy oldNFT
            
            emit FishCardTransferred(id: id, from: 0x0, to: self.owner?.address ?? panic("Collection has no owner"))
        }

        access(all) fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) fun borrowNFT(id: UInt64): &{NonFungibleToken.NFT} {
            return &self.ownedNFTs[id] as &{NonFungibleToken.NFT}
        }

        access(all) fun borrowFishCard(id: UInt64): &FishCardV1.NFT {
            return &self.ownedNFTs[id] as &FishCardV1.NFT
        }

        access(all) fun getCollectionLength(): UInt64 {
            return self.ownedNFTs.length
        }

        access(all) fun getCollectionIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) fun contains(id: UInt64): Bool {
            return self.ownedNFTs[id] != nil
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // Minter resource for minting new FishCards
    access(all) resource Minter {
        access(all) fun mintFishCard(
            recipient: Address,
            submissionStandard: SubmissionStandard,
            mediaArray: [MediaItem],
            species: String,
            length: UFix64,
            publicData: PublicData,
            privateData: PrivateData,
            verified: Verification
        ): @FishCardV1.NFT {
            // Validate media storage requirements
            for mediaItem in mediaArray {
                pre {
                    mediaItem.storageSizeBytes > 0: "Storage size must be greater than zero"
                    mediaItem.requiredFlowStake > 0.0: "Required FLOW stake must be greater than zero"
                    mediaItem.flowStoragePath.length > 0: "Flow storage path cannot be empty"
                }
            }

            FishCardV1.totalSupply = FishCardV1.totalSupply + 1
            let id = FishCardV1.totalSupply

            let nft <- create NFT(
                id: id,
                submissionStandard: submissionStandard,
                mediaArray: mediaArray,
                species: species,
                length: length,
                publicData: publicData,
                privateData: privateData,
                verified: verified,
                mintedBy: recipient
            )

            // Emit events for each media item stored
            for mediaItem in mediaArray {
                emit MediaStored(id: id, storagePath: mediaItem.flowStoragePath, storageSizeBytes: mediaItem.storageSizeBytes, requiredFlowStake: mediaItem.requiredFlowStake)
            }

            emit FishCardMinted(id: id, owner: recipient, species: species, length: length)
            return <-nft
        }
    }

    // Admin resource for contract management
    access(all) resource Admin {
        access(all) fun updateContractMetadata(
            name: String?,
            description: String?,
            externalURL: String?,
            imageURL: String?,
            socials: {String: String}?
        ) {
            if name != nil {
                FishCardV1.name = name!
            }
            if description != nil {
                FishCardV1.description = description!
            }
            if externalURL != nil {
                FishCardV1.externalURL = externalURL!
            }
            if imageURL != nil {
                FishCardV1.imageURL = imageURL!
            }
            if socials != nil {
                FishCardV1.socials = socials!
            }
        }
    }

    // ViewResolver implementation for contract
    access(all) view fun getViews(): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    access(all) view fun resolveView(_ view: Type): AnyStruct? {
        switch view {
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: self.CollectionStoragePath,
                    publicPath: self.CollectionPublicPath,
                    providerPath: /private/fishCardCollectionProvider,
                    publicCollection: Type<&FishCardV1.Collection{NonFungibleToken.CollectionPublic}>(),
                    storageType: Type<@FishCardV1.Collection>(),
                    publicLinkedType: Type<&FishCardV1.Collection{NonFungibleToken.CollectionPublic}>(),
                    privateLinkedType: Type<&FishCardV1.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.CollectionPrivate}>(),
                    publicCollectionCapability: Type<Capability<&FishCardV1.Collection{NonFungibleToken.CollectionPublic}>>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-FishCardV1.createEmptyCollection()
                    })
                )
            case Type<MetadataViews.NFTCollectionDisplay>():
                return MetadataViews.NFTCollectionDisplay(
                    name: self.name,
                    description: self.description,
                    externalURL: MetadataViews.ExternalURL(self.externalURL),
                    squareImage: MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: self.imageURL),
                        mediaType: "image/png"
                    ),
                    bannerImage: MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: self.imageURL),
                        mediaType: "image/png"
                    ),
                    socials: self.socials
                )
        }
        return nil
    }

    // Create empty collection
    access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
        return <-create Collection()
    }

    // Get total supply
    access(all) fun getTotalSupply(): UInt64 {
        return self.totalSupply
    }

    // Initialize the contract
    init() {
        self.name = "FishCard V1"
        self.symbol = "FISH"
        self.description = "Digital catch NFTs representing verified fish catches in the DerbyFish ecosystem"
        self.externalURL = "https://derby.fish"
        self.imageURL = "https://derby.fish/fishcard-logo.png"
        self.socials = {
            "website": "https://derby.fish",
            "twitter": "https://twitter.com/derby_fish"
        }
        self.totalSupply = 0

        // Set storage paths
        self.CollectionStoragePath = /storage/fishCardCollection
        self.CollectionPublicPath = /public/fishCardCollection
        self.MinterStoragePath = /storage/fishCardMinter
        self.AdminStoragePath = /storage/fishCardAdmin

        // Create and store the minter resource
        let minter <- create Minter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
        let minterCapability = self.account.capabilities.storage.issue<&FishCardV1.Minter>(self.MinterStoragePath)
        self.account.capabilities.publish(minterCapability, at: /public/fishCardMinter)

        // Create and store the admin resource
        let admin <- create Admin()
        self.account.storage.save(<-admin, to: self.AdminStoragePath)
        let adminCapability = self.account.capabilities.storage.issue<&FishCardV1.Admin>(self.AdminStoragePath)
        self.account.capabilities.publish(adminCapability, at: /public/fishCardAdmin)

        emit ContractInitialized()
    }
}
