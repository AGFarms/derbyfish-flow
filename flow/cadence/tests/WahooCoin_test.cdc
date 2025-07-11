import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "WahooCoin",
        path: "../contracts/WahooCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}