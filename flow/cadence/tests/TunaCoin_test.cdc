import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "TunaCoin",
        path: "../contracts/TunaCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}