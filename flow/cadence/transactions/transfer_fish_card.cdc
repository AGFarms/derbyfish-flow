import "FishNFT"
import "NonFungibleToken"

/// This transaction transfers a FishCard NFT from one account to another
transaction(recipient: Address, cardId: UInt64) {
    /// Reference to the withdrawer's collection
    let withdrawRef: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}

    /// Reference of the collection to deposit the NFT to
    let receiverRef: &{NonFungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {
        // borrow a reference to the signer's NFT collection
        self.withdrawRef = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(
            from: FishNFT.FishCardCollectionStoragePath
        ) ?? panic("The signer does not store a FishCard Collection object at the path "
                    .concat(FishNFT.FishCardCollectionStoragePath.toString())
                    .concat("The signer must initialize their account with this collection first!"))

        // get the recipients public account object
        let recipient = getAccount(recipient)

        // borrow a public reference to the receivers collection
        let receiverCap = recipient.capabilities.get<&{NonFungibleToken.Receiver}>(FishNFT.FishCardCollectionPublicPath)

        self.receiverRef = receiverCap.borrow()
            ?? panic("The account ".concat(recipient.address.toString()).concat(" does not have a NonFungibleToken Receiver at ")
                .concat(FishNFT.FishCardCollectionPublicPath.toString())
                .concat(". The account must initialize their account with this collection first!"))
    }

    execute {
        let nft <- self.withdrawRef.withdraw(withdrawID: cardId)
        self.receiverRef.deposit(token: <-nft)
    }
}