import "NonFungibleToken"
import "Fish"
import "MetadataViews"

transaction(
    recipient: Address
) {

    /// local variable for storing the minter reference
    let minter: &Fish.NFTMinter

    /// Reference to the receiver's collection
    let recipientCollectionRef: &{NonFungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {

        // borrow a reference to the NFTMinter resource in storage
        self.minter = signer.storage.borrow<&Fish.NFTMinter>(from: Fish.MinterStoragePath)
            ?? panic("The signer does not store a Fish Minter object at the path "
                        .concat(Fish.MinterStoragePath.toString())
                        .concat("The signer must initialize their account with this minter first!"))

        // Borrow the recipient's public NFT collection reference
        self.recipientCollectionRef = getAccount(recipient).capabilities.borrow<&{NonFungibleToken.Receiver}>(
                Fish.CollectionPublicPath
        ) ?? panic("The account ".concat(recipient.toString()).concat(" does not have a NonFungibleToken Receiver at ")
                .concat(Fish.CollectionPublicPath.toString())
                .concat(". The account must initialize their account with this collection first!"))
    }

    execute {
        // Mint the NFT and deposit it to the recipient's collection
        let mintedNFT <- self.minter.mintNFT(
            name: "DerbyFish NFT",
            description: "A unique fish NFT from the DerbyFish ecosystem",
            thumbnail: "https://example.com/fish-thumbnail.png",
            royalties: []
        )
        self.recipientCollectionRef.deposit(token: <-mintedNFT)
    }
}
