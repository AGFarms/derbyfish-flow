import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "SnookCoin",
        path: "../contracts/SnookCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}