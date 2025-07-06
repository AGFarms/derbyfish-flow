import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "TroutCoin",
        path: "../contracts/TroutCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}