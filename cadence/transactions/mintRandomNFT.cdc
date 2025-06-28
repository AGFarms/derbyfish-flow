import "EFishUnverifiedNFT"
import "EFishVerifiedNFT"

transaction(    
    bump: String,
    bumpHash: String,
    hero: String,
    heroHash: String,
    release: [String],
    releaseHashes: [String]
) {

    let acct: auth(Capabilities, Storage) &Account

    prepare(acct: auth(Capabilities, Storage) &Account) {
        log(acct.address)
        self.acct = acct
    }

    execute {
        // Mint new NFT
        if self.acct.storage.type(at: EFishVerifiedNFT.CollectionStoragePath) == nil {
            let verifiedCollection <- EFishVerifiedNFT.createEmptyCollection(nftType: Type<@EFishVerifiedNFT.NFT>())
            self.acct.storage.save(<-verifiedCollection, to: EFishVerifiedNFT.CollectionStoragePath)

            let cap = self.acct.capabilities.storage.issue<&EFishVerifiedNFT.Collection>(EFishVerifiedNFT.CollectionStoragePath)
            self.acct.capabilities.publish(cap, at: EFishVerifiedNFT.CollectionPublicPath)
        }

        EFishUnverifiedNFT.submitNFT(         
            bump: bump,
            bumpHash: bumpHash,
            hero: hero,
            heroHash: heroHash,
            release: release,
            releaseHashes: releaseHashes,
            flowAddress: self.acct.address
        )

    }
}
