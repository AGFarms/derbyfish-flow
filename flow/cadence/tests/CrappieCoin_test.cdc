import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "CrappieCoin",
        path: "../contracts/CrappieCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}