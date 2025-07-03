# Successful FishNFT Mint Example (Flow CLI + Inline JSON)

This document shows a working example of minting a FishNFT using the Flow CLI with inline JSON arguments. This approach is robust and avoids issues with negative numbers, optionals, and address formatting.

---

## 1. **Command Used**

```bash
flow transactions send cadence/transactions/mint_fish_nft.cdc \
  --args-json '[
    {"type":"Address","value":"0x179b6b1cb6755e31"},
    {"type":"String","value":"https://example.com/walleye-bump-1.jpg"},
    {"type":"String","value":"https://example.com/walleye-hero-1.jpg"},
    {"type":"Bool","value":true},
    {"type":"Optional","value":{"type":"String","value":"https://example.com/walleye-release-1.mp4"}},
    {"type":"String","value":"walleye-bump-hash-123"},
    {"type":"String","value":"walleye-hero-hash-456"},
    {"type":"Optional","value":{"type":"String","value":"walleye-release-hash-789"}},
    {"type":"Fix64","value":"-93.2650"},
    {"type":"Fix64","value":"44.9778"},
    {"type":"UFix64","value":"24.5"},
    {"type":"String","value":"Walleye"},
    {"type":"String","value":"Sander vitreus"},
    {"type":"UFix64","value":"1699123456.0"},
    {"type":"Optional","value":{"type":"String","value":"Jig and minnow"}},
    {"type":"Optional","value":{"type":"String","value":"Lake Minnetonka, MN"}}
  ]' \
  --signer emulator-account \
  --network emulator
```

---

## 2. **Key Points**
- **Addresses** must have a `0x` prefix (e.g., `0x179b6b1cb6755e31`).
- **UFix64/Fix64** values must have a decimal point (e.g., `"1699123456.0"`).
- **Optionals** are wrapped as `{ "type": "Optional", "value": ... }`.
- The `--args-json` value is a single-quoted, valid JSON array of Cadence value objects.

---

## 3. **What to Check for Success**
- Transaction status: `✅ SEALED`
- Events:
  - `FishMinted` with correct metadata (species, length, etc.)
  - `NonFungibleToken.Deposited` confirming NFT deposit
- No errors about argument count, address format, or decimal points

---

## 4. **How to Verify**
- Run:
  ```bash
  flow scripts execute cadence/scripts/get_fish_ids.cdc 0x179b6b1cb6755e31 --network emulator
  ```
- Check for the new NFT ID in the output.

---

## 5. **Troubleshooting**
- If you get errors about argument count, check the number and order of JSON objects.
- If you get errors about address format, ensure all addresses start with `0x`.
- If you get errors about decimal points, ensure all `UFix64`/`Fix64` values have a decimal (e.g., `"24.5"`, not `"24"`).

---

**This method is robust for all Cadence types and is recommended for complex transactions!** 