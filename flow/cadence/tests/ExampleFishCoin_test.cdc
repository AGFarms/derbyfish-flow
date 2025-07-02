import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "ExampleFishCoin",
        path: "../contracts/ExampleFishCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}