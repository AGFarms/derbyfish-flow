import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "BaitCoin",
        path: "../contracts/BaitCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}