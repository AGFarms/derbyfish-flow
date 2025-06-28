access(all) contract UnverifiedFishScan {
    access(all) var totalSupply: UInt64
    access(all) let contractOwner: Address

    access(all) resource NFT {
        access(all) let id: UInt64
        access(all) let bump: String
        access(all) let bumpHash: String
        access(all) let hero: String
        access(all) let heroHash: String
        access(all) let release: [String]
        access(all) let releaseHashes: [String]
        access(all) var verifiedVotes: {Address: Bool}
        access(all) var rejectedVotes: {Address: Bool}

        init(
            id: UInt64,
            bump: String,
            bumpHash: String,
            hero: String,
            heroHash: String,
            release: [String],
            releaseHashes: [String]
        ) {
            self.id = id
            self.bump = bump
            self.bumpHash = bumpHash
            self.hero = hero
            self.heroHash = heroHash
            self.release = release
            self.releaseHashes = releaseHashes
            self.verifiedVotes = {}
            self.rejectedVotes = {}
        }

        access(all) fun vote(voter: Address, verified: Bool) {
            // Ensure voter is not the contract owner
            if voter == UnverifiedFishScan.contractOwner {
                panic("Contract owner cannot vote")
            }

            // Remove any existing votes by this voter
            self.verifiedVotes.remove(key: voter)
            self.rejectedVotes.remove(key: voter)

            // Add the new vote
            if verified {
                self.verifiedVotes[voter] = true
            } else {
                self.rejectedVotes[voter] = true
            }
        }

        access(all) fun getVoteCounts(): {String: Int} {
            return {
                "verified": self.verifiedVotes.length,
                "rejected": self.rejectedVotes.length
            }
        }

        access(all) fun hasVoted(address: Address): Bool {
            return self.verifiedVotes[address] != nil || self.rejectedVotes[address] != nil
        }
    }

    access(all) resource Collection {
        access(all) var ownedNFTs: @{UInt64: NFT}

        init() {
            self.ownedNFTs <- {}
        }

        access(all) fun deposit(token: @NFT) {
            self.ownedNFTs[token.id] <-! token
        }

        access(all) fun withdraw(withdrawID: UInt64): @NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("NFT not found in collection")
            return <- token
        }

        access(all) fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) fun voteOnNFT(voter: Address, id: UInt64, verified: Bool) {
            let nft = &self.ownedNFTs[id] as &NFT? 
                ?? panic("NFT not found")
            nft.vote(voter: voter, verified: verified)
        }
    }

    access(all) fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    access(all) fun mintNFT(
        bump: String,
        bumpHash: String,
        hero: String,
        heroHash: String,
        release: [String],
        releaseHashes: [String]
    ): @NFT {
        let newNFT <- create NFT(
            id: self.totalSupply,
            bump: bump,
            bumpHash: bumpHash,
            hero: hero,
            heroHash: heroHash,
            release: release,
            releaseHashes: releaseHashes
        )
        self.totalSupply = self.totalSupply + 1
        return <- newNFT
    }

    init() {
        self.totalSupply = 0
        self.contractOwner = self.account.address
    }
} 