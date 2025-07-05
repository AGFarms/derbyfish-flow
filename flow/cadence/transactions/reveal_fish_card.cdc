import "FishNFT"
import "NonFungibleToken"

/// This transaction reveals a committed FishCard using the stored receipt
/// Must be called at least 1 block after the commit
transaction(commitId: UInt64) {
    prepare(acct: auth(Storage, BorrowValue) &Account) {
        // Get the receipt
        let receipt <- acct.storage.load<@FishNFT.FishCardReceipt>(from: FishNFT.FishCardReceiptStoragePath)
            ?? panic("Could not load FishCard receipt")

        // Get the collection reference
        let collectionRef = acct.storage.borrow<&FishNFT.FishCardCollection>(from: FishNFT.FishCardCollectionStoragePath)
            ?? panic("Could not borrow FishCard collection")

        // Reveal the FishCard
        let fishCard <- FishNFT.revealFishCard(receipt: <-receipt)

        // Deposit the FishCard into the collection
        collectionRef.deposit(token: <-fishCard)
    }
} 