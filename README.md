## derbyfish-flow Tokenomics & Architecture

### 1. Token Roles & Mechanics

**Bait (Stablecoin)**

* **Pegging model**: Strict 1:1 backing with USDC reserves.
* **Minting/Burning**: Any user can mint by depositing USDC; burning via redeeming on‑chain or off‑chain KYC process through DerbyFish or partnered DEX.
* **Redemption**: KYC-enabled in-app redemption or through integrated DEX.

**SpeciesCoin**

* **Mining rule**: 1 SpeciesCoin awarded per verified Fish NFT mint event.
* **Supply cap**: Uncapped, but minted only via fish verification—natural issuance control.
* **Initial distribution**: Private in‑app sale at predefined price, then opened to market via AMM liquidity pool.

### 2. Economic Flows & Marketplace

**FishCards ↔ Bait**

* **Exchange mechanics**: Dynamic rate—FishCards sell for Bait at market-driven value (pegged via liquidity pool price) minus transaction fee.
* **Anti‑abuse**: Standard Flow transaction fees and optional cooldowns to deter wash‑trading.

**SpeciesCoin ↔ Bait Market**

* **DEX model**: Automated Market Maker (AMM).
* **Initial liquidity**: App buys minted SpeciesCoin from anglers, then seeds SpeciesCoin–Bait pool on chain.
* **Ongoing liquidity**: Part of each private sale and transaction fees reinvested into pool.

**In‑App & In‑Store Use Cases**

* **Spend Bait on**: Derby tickets, memberships, merchandise, FishCards, Fish Packs.
* **Merchant integration**: Target bait & tackle shops to accept Bait on‑chain or via custodial abstraction.

### 3. Technical & Flow Integration

**Cadence Contracts**

* Implement FungibleToken standards for both Bait and SpeciesCoin.
* Use contract upgradeability patterns for emergency fixes.

**Bridging & Liquidity**

* Bridge USDC into Flow via LayerZero/Stargate for reserve backing.
* KYC flow embedded in the app for large redemptions; small redemptions on‑chain.

### 4. Governance, Compliance & Security

* **Governance**: Centralized—no DAO initially. DerbyFish retains mint/burn control.
* **KYC/AML**: Mandatory in‑app KYC for USD redemptions and merchant partnerships; legal/accounting processes under development.
* **Audits**: Schedule independent smart‑contract audits post‑MVP.

### 5. User Onboarding & Experience

* **Wallet integration**: Custodial, abstracted Flow accounts via Dapper/Modd® SDK—users remain unaware of Web3 complexity.
* **Fiat on‑ramp**: Seamless credit card purchase of Bait through integrated payment processor.
* **Fish mint & earn flow**: Single transaction: verify fish → mint NFT + 1 SpeciesCoin to user’s custodial account.

---

**Next Steps**

1. Draft Cadence contract templates for Bait & SpeciesCoin.
2. Design private‑sale UI for initial SpeciesCoin distribution.
3. Integrate LayerZero bridge for USDC inflows.
4. Build KYC & redemption backend workflows.
5. Plan first smart‑contract audit.