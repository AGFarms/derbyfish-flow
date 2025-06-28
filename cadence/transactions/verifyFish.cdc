import "EFishUnverifiedNFT"
import "EFishVerifiedNFT"
import "NonFungibleToken"

transaction(    
    nftID: UInt64,
    verified: Bool
) {
    let collection: auth(EFishUnverifiedNFT.Verifier) &EFishUnverifiedNFT.Collection

    prepare(acct: auth(Capabilities, Storage) &Account) {
        self.collection = acct.storage.borrow<auth(EFishUnverifiedNFT.Verifier) &EFishUnverifiedNFT.Collection>(from: EFishUnverifiedNFT.CollectionStoragePath)
        ?? panic("Could not find collection")
        
    }

    execute {
        self.collection.finalJudge(nftID: nftID, decision: verified)
    }
}
