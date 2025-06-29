## DerbyFish Flow Tokenomics & Architecture

### Overview

DerbyFish uses a dual‑token model on Flow:

* **Bait**: A 1:1 USDC‑backed stablecoin for in‑app purchases, marketplace transactions, and merchant integrations.
* **SpeciesCoins**: One fungible token contract per fish species (e.g., WalleyeCoin, BassCoin), minted by anglers when they verify a catch and mint a FishNFT.
* **FishNFTs**: Non‑fungible tokens representing the actual catch, storing full metadata (species, GPS, time, gear). Users can optionally mint **Trading‑Card NFTs** derived from their FishNFT.
* **Badges**: On‑chain, soulbound Badge NFTs granted on first‑catch per species (extendable to location or gear achievements).

---

### 1. Token Roles & Mechanics

#### Bait (Stablecoin)

* **Pegging & Reserves**: Strictly 1:1 backed by USDC. Reserves held in a multi‑sig vault with time‑locks and proof‑of‑reserves snapshots available in‑app.
* **Mint/Burn**: Users mint Bait by depositing USDC via in‑app custodial flows; burn by redeeming USDC on‑chain or through a KYC‑gate in the app.
* **Gas Sponsorship**: DerbyFish pays all Flow gas; users never see transaction fees.

#### SpeciesCoins (Per Species)

* **Deployment**: A `SpeciesCoinFactory` contract allows on‑chain registration of new species IDs and dynamic creation of fungible token contracts (e.g., `WalleyeCoin`).
* **Minting**: `mintSpeciesCoin(speciesID, 1)` is called automatically in the Fish‑mint transaction, crediting the angler with 1 token.
* **Supply**: Capped to the total number of FishNFTs ever minted for that species; future caps enforced via upgradeable contract governance.

---

### 2. NFT Architecture

#### FishNFT

* Implements `NonFungibleToken`, stores catch metadata (GPS, timestamp, gear, photos).
* Serves as the canonical proof of catch and key to minting SpeciesCoin.

#### Trading‑Card NFTs

* Users may mint up to an upgradeable limit of “card edition” NFTs from an existing FishNFT.
* Cards reference the FishNFT ID and optionally include or omit personal metadata for privacy.
* Card metadata and artwork templates managed via a central registry contract.

#### Badge NFTs

* On first‐catch per species, a soulbound Badge NFT is minted to the user’s account.
* Badges include speciesID and timestamp metadata; non‑transferable.
* Extendable to other badge categories (locations, gear, leaderboards).

---

### 3. Fishdex & Badging System

* **On‑Chain Events**: `FishMinted` and `BadgeAwarded` events trigger off‑chain amplification to update the Fishdex UI.
* **Fishdex UI**: Displays species sightings, badge collections, gear logs, and geographic heatmaps.
* **Rewards**: First‑catch badges unlock UI achievements; can integrate bonus SpeciesCoin airdrops in future.

---

### 4. Marketplace & Economic Flows

#### FishCards ↔ Bait

* Fish trading‑card NFTs can be listed in the in‑app marketplace for Bait at dynamic, market‑driven prices.

#### SpeciesCoin ↔ Bait

* Initial private sale per species at a fixed price in Bait, handled by a `PrivateSale` contract.
* Post‑sale, DerbyFish seeds an AMM pool (`SpeciesCoin–Bait`) and reinvests a portion of fees to maintain liquidity.

#### Merchant & In‑Store Use Cases

* DerbyFish SDK for Web POS: Merchants accept Bait via custodial API; DerbyFish settles USDC off‑chain.

---

### 5. Security & Compliance

* **Multi‑Sig Vaults**: USDC reserves in 2‑of‑3 multi‑sig with 48‑hour timelock.
* **Audits**: Engage CertiK/Consensys for Cadence contracts; SOC 2 for backend.
* **KYC/AML**: All fiat on‑ramps/redemptions require in‑app KYC; small spot trades gas‑only.

---

### 6. UX & Onboarding

* **Custodial Accounts**: Email‑OTP flow via Dapper SDK abstracts Flow accounts.
* **Gasless**: All gas sponsored; users only see Bait balances.
* **Fiat On‑Ramp**: Single “Buy Bait” button routes through ACH, card, or crypto on‑ramp based on cost/latency.
* **Recovery**: Email‑based key recovery; optional social‑recovery through guardians.

---

### Next Steps

1. **Cadence Templates**: Generate `SpeciesCoinFactory`, `FishNFT`, `TradingCard`, `BadgeNFT`, and `PrivateSale` contract skeletons.
2. **Private Sale UI**: Design flow & smart contract for fixed‑price species launches.
3. **SDK Integration**: Build SDK wrappers for minting, badge claiming, and marketplace listing.
4. **Audit & Launch**: Schedule security audits and prepare mainnet rollout plan.
