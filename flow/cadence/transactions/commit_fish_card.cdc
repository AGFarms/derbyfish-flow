import "FishNFT"

/// This transaction commits a FishCard mint request with user-provided salt
/// The receipt must be saved for the reveal phase
/// @param userSalt: Array of 8 bytes for randomness, e.g. [1,2,3,4,5,6,7,8]
transaction(
    fishNFTId: UInt64,
    fishNFTOwner: Address,
    recipient: Address,
    userSalt: [UInt8]
) {
    prepare(acct: auth(Storage) &Account) {
        // Get FishCard receipt capability
        let receiptStoragePath = FishNFT.FishCardReceiptStoragePath

        // Request FishCard mint and get receipt
        let receipt <- FishNFT.commitFishCard(
            fishNFTId: fishNFTId,
            fishNFTOwner: fishNFTOwner,
            recipient: recipient,
            userSalt: userSalt
        )

        // Save receipt for later reveal
        acct.storage.save(<-receipt, to: receiptStoragePath)
    }
} 