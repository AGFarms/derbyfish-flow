import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"

access(all) contract FishNFT: NonFungibleToken {

    // SPECIES COIN INTEGRATION - Simple registry approach
    access(all) var speciesRegistry: {String: Address}  // speciesCode -> contract address
    access(all) var totalFishCaught: UInt64

    // Storage paths
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

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
        timestamp: UFix64
    )

    access(all) struct FishMetadata {
        access(all) let bumpShotUrl: String
        access(all) let heroShotUrl: String
        access(all) let hasRelease: Bool
        access(all) let releaseVideoUrl: String?
        access(all) let bumpHash: String
        access(all) let heroHash: String
        access(all) let releaseHash: String?
        access(all) let longitude: Fix64
        access(all) let latitude: Fix64
        access(all) let length: UFix64
        access(all) let species: String
        access(all) let scientific: String
        access(all) let timestamp: UFix64
        access(all) let gear: String?
        access(all) let location: String?
        
        // Simple species integration
        access(all) let speciesCode: String?        // Species code (e.g., "SANDER_VITREUS")

        init(
            bumpShotUrl: String,
            heroShotUrl: String,
            hasRelease: Bool,
            releaseVideoUrl: String?,
            bumpHash: String,
            heroHash: String,
            releaseHash: String?,
            longitude: Fix64,
            latitude: Fix64,
            length: UFix64,
            species: String,
            scientific: String,
            timestamp: UFix64,
            gear: String?,
            location: String?,
            speciesCode: String?
        ) {
            self.bumpShotUrl = bumpShotUrl
            self.heroShotUrl = heroShotUrl
            self.hasRelease = hasRelease
            self.releaseVideoUrl = releaseVideoUrl
            self.bumpHash = bumpHash
            self.heroHash = heroHash
            self.releaseHash = releaseHash
            self.longitude = longitude
            self.latitude = latitude
            self.length = length
            self.species = species
            self.scientific = scientific
            self.timestamp = timestamp
            self.gear = gear
            self.location = location
            self.speciesCode = speciesCode
        }
    }

    access(all) resource NFT: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) let metadata: FishMetadata
        access(all) let mintedBy: Address
        access(all) let mintedAt: UFix64

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
                            name: "Latitude",
                            value: self.metadata.latitude,
                            displayType: "Number",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Longitude",
                            value: self.metadata.longitude,
                            displayType: "Number",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Has Release",
                            value: self.metadata.hasRelease,
                            displayType: "Boolean",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "Catch Date",
                            value: self.metadata.timestamp,
                            displayType: "Date",
                            rarity: nil
                        )
                    ]

                    if let gear = self.metadata.gear {
                        traits.append(
                            MetadataViews.Trait(
                                name: "Gear",
                                value: gear,
                                displayType: "String",
                                rarity: nil
                            )
                        )
                    }

                    if let location = self.metadata.location {
                        traits.append(
                            MetadataViews.Trait(
                                name: "Location",
                                value: location,
                                displayType: "String",
                                rarity: nil
                            )
                        )
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
                timestamp: metadata.timestamp
            )

            // Update total fish caught counter
            FishNFT.totalFishCaught = FishNFT.totalFishCaught + 1

            // Process species coin minting if species code provided and registered
            if let speciesCode = metadata.speciesCode {
                if let contractAddress = FishNFT.speciesRegistry[speciesCode] {
                    FishNFT.mintSpeciesCoins(
                        fishNFTId: self.nextID, 
                        speciesCode: speciesCode, 
                        angler: recipient,
                        contractAddress: contractAddress
                    )
                }
            }

            self.nextID = self.nextID + 1

            return <-newNFT
        }
        
        // Enhanced mint function with species validation
        access(all) fun mintNFTWithSpeciesValidation(
            recipient: Address,
            bumpShotUrl: String,
            heroShotUrl: String,
            hasRelease: Bool,
            releaseVideoUrl: String?,
            bumpHash: String,
            heroHash: String,
            releaseHash: String?,
            longitude: Fix64,
            latitude: Fix64,
            length: UFix64,
            species: String,
            scientific: String,
            timestamp: UFix64,
            gear: String?,
            location: String?,
            speciesCode: String
        ): @FishNFT.NFT {
            
            // Create metadata with species code
            let metadata = FishMetadata(
                bumpShotUrl: bumpShotUrl,
                heroShotUrl: heroShotUrl,
                hasRelease: hasRelease,
                releaseVideoUrl: releaseVideoUrl,
                bumpHash: bumpHash,
                heroHash: heroHash,
                releaseHash: releaseHash,
                longitude: longitude,
                latitude: latitude,
                length: length,
                species: species,
                scientific: scientific,
                timestamp: timestamp,
                gear: gear,
                location: location,
                speciesCode: speciesCode
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
                    externalURL: MetadataViews.ExternalURL("https://derbyfish.flow.org"),
                    squareImage: MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: "https://derbyfish.flow.org/images/logo-square.png"),
                        mediaType: "image/png"
                    ),
                    bannerImage: MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: "https://derbyfish.flow.org/images/banner.png"),
                        mediaType: "image/png"
                    ),
                    socials: {
                        "website": MetadataViews.ExternalURL("https://derbyfish.flow.org"),
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/derbyfish")
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

    // Species coin minting function
    access(all) fun mintSpeciesCoins(fishNFTId: UInt64, speciesCode: String, angler: Address, contractAddress: Address) {
        // For now, just emit an event that species coin should be minted
        // The actual minting logic will be handled by a separate transaction
        // This keeps the FishNFT contract simple and decoupled
        log("Species coin minting requested for: ".concat(speciesCode).concat(" to angler: ").concat(angler.toString()))
    }

    init() {
        self.CollectionStoragePath = /storage/FishNFTCollection
        self.CollectionPublicPath = /public/FishNFTCollection
        self.MinterStoragePath = /storage/FishNFTMinter

        // Initialize species integration variables
        self.speciesRegistry = {}
        self.totalFishCaught = 0

        let collection <- create Collection()
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)

        let collectionCap = self.account.capabilities.storage.issue<&FishNFT.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(collectionCap, at: self.CollectionPublicPath)

        let minter <- create NFTMinter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
    }
} 