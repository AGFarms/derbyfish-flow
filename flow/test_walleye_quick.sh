#!/bin/bash

# Quick Walleye NFT Testing Script
# Usage: ./test_walleye_quick.sh [emulator|testnet]

NETWORK=${1:-emulator}
if [ "$NETWORK" = "emulator" ]; then
    ACCOUNT="emulator-account"
    ADDRESS="0xf8d6e0586b0a20c7"
elif [ "$NETWORK" = "testnet" ]; then
    ACCOUNT="testnet-account"  
    ADDRESS="0x5a8151874f113819"
else
    echo "❌ Invalid network. Use 'emulator' or 'testnet'"
    exit 1
fi

echo "🎣 Starting Walleye NFT Testing on $NETWORK"
echo "📍 Using account: $ADDRESS"
echo

# Phase 1: Setup collection
echo "🔧 Phase 1: Setting up FishNFT collection..."
flow transactions send cadence/transactions/setup_fish_nft_collection.cdc \
    --signer $ACCOUNT --network $NETWORK

if [ $? -eq 0 ]; then
    echo "✅ Collection setup successful"
else
    echo "❌ Collection setup failed"
    exit 1
fi

sleep 2

# Phase 2: Check initial state
echo
echo "📊 Phase 2: Checking initial collection state..."
INITIAL_COUNT=$(flow scripts execute cadence/scripts/get_fish_ids.cdc $ADDRESS --network $NETWORK)
echo "Initial NFT count: $INITIAL_COUNT"

# Phase 3: Mint first Walleye NFT
echo
echo "🐟 Phase 3: Minting first Walleye NFT..."
flow transactions send cadence/transactions/mint_fish_nft.cdc \
    $ADDRESS \
    "https://example.com/walleye-bump-1.jpg" \
    "https://example.com/walleye-hero-1.jpg" \
    true \
    "https://example.com/walleye-release-1.mp4" \
    "walleye-bump-hash-123" \
    "walleye-hero-hash-456" \
    "walleye-release-hash-789" \
    -93.2650 \
    44.9778 \
    24.5 \
    "Walleye" \
    "Sander vitreus" \
    1699123456 \
    "Jig and minnow" \
    "Lake Minnetonka, MN" \
    --signer $ACCOUNT --network $NETWORK

if [ $? -eq 0 ]; then
    echo "✅ First Walleye NFT minted successfully"
else
    echo "❌ First Walleye NFT minting failed"
    exit 1
fi

sleep 2

# Phase 4: Mint second Walleye NFT
echo
echo "🐟 Phase 4: Minting second Walleye NFT..."
flow transactions send cadence/transactions/mint_fish_nft.cdc \
    $ADDRESS \
    "https://example.com/walleye-bump-2.jpg" \
    "https://example.com/walleye-hero-2.jpg" \
    false \
    null \
    "walleye-bump-hash-234" \
    "walleye-hero-hash-567" \
    null \
    -93.6632 \
    46.2659 \
    18.75 \
    "Walleye" \
    "Sander vitreus" \
    1699210000 \
    "Trolling with crawler harness" \
    "Mille Lacs Lake, MN" \
    --signer $ACCOUNT --network $NETWORK

if [ $? -eq 0 ]; then
    echo "✅ Second Walleye NFT minted successfully"
else
    echo "❌ Second Walleye NFT minting failed"
    exit 1
fi

sleep 2

# Phase 5: Verify results
echo
echo "🔍 Phase 5: Verifying minting results..."
FINAL_COUNT=$(flow scripts execute cadence/scripts/get_fish_ids.cdc $ADDRESS --network $NETWORK)
echo "Final NFT count: $FINAL_COUNT"

# Phase 6: Run comprehensive analysis
echo
echo "📈 Phase 6: Running Walleye analysis..."
echo "Running comprehensive Walleye NFT analysis script..."
flow scripts execute cadence/scripts/test_walleye_nft.cdc $ADDRESS --network $NETWORK

echo
echo "🎉 Walleye NFT testing completed!"
echo
echo "📋 Summary:"
echo "- Network: $NETWORK"
echo "- Account: $ADDRESS"
echo "- Initial NFTs: $INITIAL_COUNT"
echo "- Final NFTs: $FINAL_COUNT" 
echo
echo "🔗 Next steps:"
echo "1. Check the analysis results above"
echo "2. Try minting different fish species"
echo "3. Test species coin integration"
echo "4. Test on the other network ($([[ $NETWORK == 'emulator' ]] && echo 'testnet' || echo 'emulator'))"
echo
echo "📖 For detailed testing, see: WALLEYE_NFT_TESTING_GUIDE.md" 