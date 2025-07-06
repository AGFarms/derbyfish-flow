import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "TarponCoin",
        path: "../contracts/TarponCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}