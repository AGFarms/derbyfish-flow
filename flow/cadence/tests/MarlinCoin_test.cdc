import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "MarlinCoin",
        path: "../contracts/MarlinCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}