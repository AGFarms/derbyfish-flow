import "NonFungibleToken"
import "MetadataViews"

access(all) contract EFishVerifiedNFT: NonFungibleToken {

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    access(all) resource NFTMinter {
        access(all) fun mintNFT(
            flowAddress: Address,
            bump: String,
            bumpHash: String,
            hero: String,
            heroHash: String,
            release: [String],
            releaseHashes: [String]
        ): @EFishVerifiedNFT.NFT {
            return <- create NFT(
                bump: bump,
                bumpHash: bumpHash,
                hero: hero,
                heroHash: heroHash,
                release: release,
                releaseHashes: releaseHashes
            )
        }
    }

    access(all) resource NFT: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) let bump: String
        access(all) let bumpHash: String
        access(all) let hero: String
        access(all) let heroHash: String
        access(all) let release: [String]
        access(all) let releaseHashes: [String]
        access(all) var verifiedVotes: {Address: Bool}
        access(all) var rejectedVotes: {Address: Bool}
        access(all) var data: {String: AnyStruct}
        access(all) var resources: @{String: AnyResource}

        init(
            bump: String,
            bumpHash: String,
            hero: String,
            heroHash: String,
            release: [String],
            releaseHashes: [String]
        ) {
            self.id = self.uuid
            self.bump = bump
            self.bumpHash = bumpHash
            self.hero = hero
            self.heroHash = heroHash
            self.release = release
            self.releaseHashes = releaseHashes
            self.verifiedVotes = {}
            self.rejectedVotes = {}
            self.data = {}
            self.resources <-{}
        }

        access(all) fun verify(voter: Address) {
            self.verifiedVotes[voter] = true
            if self.rejectedVotes[voter] != nil {
                self.rejectedVotes.remove(key: voter)
            }
        }

        access(all) fun reject(voter: Address) {
            self.rejectedVotes[voter] = true
            if self.verifiedVotes[voter] != nil {
                self.verifiedVotes.remove(key: voter)
            }
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "EFish NFT",
                        description: "An Ethical Fish NFT",
                        thumbnail: MetadataViews.HTTPFile(url: "https://ethicalfish.xyz/logo.png")
                    )
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-EFishVerifiedNFT.createEmptyCollection(nftType: Type<@EFishVerifiedNFT.NFT>())
        }
    }

    access(account) fun mint(
        bump: String,
        bumpHash: String,
        hero: String,
        heroHash: String,
        release: [String],
        releaseHashes: [String]
    ): @EFishVerifiedNFT.NFT {
        let nft <- create NFT(
            bump: bump,
            bumpHash: bumpHash,
            hero: hero,
            heroHash: heroHash,
            release: release,
            releaseHashes: releaseHashes,
        )

        return <-nft
    }

    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init () {
            self.ownedNFTs <- {}
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@EFishVerifiedNFT.NFT>()] = true
            return supportedTypes
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@EFishVerifiedNFT.NFT>()
        }

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("EFishNFT.Collection.withdraw: Could not withdraw NFT with ID ".concat(withdrawID.toString()))
            return <-token
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @EFishVerifiedNFT.NFT
            let id = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            destroy oldToken
        }

        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) view fun getLength(): Int {
            return self.ownedNFTs.length
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-EFishVerifiedNFT.createEmptyCollection(nftType: Type<@EFishVerifiedNFT.NFT>())
        }
    }

    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    access(account) fun finalJudge(nftID: UInt64, decision: Bool) {
        
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: self.CollectionStoragePath,
                    publicPath: self.CollectionPublicPath,
                    publicCollection: Type<&EFishVerifiedNFT.Collection>(),
                    publicLinkedType: Type<&EFishVerifiedNFT.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-EFishVerifiedNFT.createEmptyCollection(nftType: Type<@EFishVerifiedNFT.NFT>())
                    })
                )
            case Type<MetadataViews.NFTCollectionDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://ethicalfish.xyz/logo.png"
                    ),
                    mediaType: "image/png"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "EFish Collection",
                    description: "Collection of Ethical Fish NFTs",
                    externalURL: MetadataViews.ExternalURL("https://ethicalfish.xyz"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {}
                )
        }
        return nil
    }

    init() {
        self.CollectionStoragePath = /storage/EFishVerifiedNFTCollection
        self.CollectionPublicPath = /public/EFishVerifiedNFTCollection
        self.MinterStoragePath = /storage/EFishVerifiedNFTMinter

        let collection <- create Collection()
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)

        let collectionCap = self.account.capabilities.storage.issue<&EFishVerifiedNFT.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(collectionCap, at: self.CollectionPublicPath)

        let minter <- create NFTMinter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
    }
} 