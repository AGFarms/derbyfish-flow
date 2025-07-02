import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"

access(all) contract FishNFT: NonFungibleToken {

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

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
            location: String?
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

        access(all) fun getViews(): [Type] {
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
    }

    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init() {
            self.ownedNFTs <- {}
        }

        access(all) fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@FishNFT.NFT>()] = true
            return supportedTypes
        }

        access(all) fun isSupportedNFTType(type: Type): Bool {
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

        access(all) fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) fun getLength(): Int {
            return self.ownedNFTs.length
        }

        access(all) fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)
        }

        access(all) fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
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
                mintedBy: self.account.address
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

            self.nextID = self.nextID + 1

            return <-newNFT
        }

        access(all) fun mintNFTToCollection(
            recipient: &{NonFungibleToken.Collection},
            metadata: FishMetadata
        ) {
            let nft <- self.mintNFT(
                recipient: recipient.owner?.address ?? self.account.address,
                metadata: metadata
            )
            recipient.deposit(token: <-nft)
        }
    }

    init() {
        self.CollectionStoragePath = /storage/FishNFTCollection
        self.CollectionPublicPath = /public/FishNFTCollection
        self.MinterStoragePath = /storage/FishNFTMinter

        let collection <- create Collection()
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)

        let collectionCap = self.account.capabilities.storage.issue<&FishNFT.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(collectionCap, at: self.CollectionPublicPath)

        let minter <- create NFTMinter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
    }
} 