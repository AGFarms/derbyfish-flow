import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "RedfishCoin",
        path: "../contracts/RedfishCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}