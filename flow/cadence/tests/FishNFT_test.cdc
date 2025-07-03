import Test

access(all) let admin = Test.createAccount()
access(all) let angler = Test.createAccount()

access(all) fun testContract() {
    // Test contract deployment
    let err = Test.deployContract(
        name: "FishNFT",
        path: "../contracts/FishNFT.cdc",
        arguments: [],
    )
    Test.expect(err, Test.beNil())
    
    // Log success for basic deployment test
    log("✅ FishNFT contract deployed successfully")
} 