import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "RandomConsumer",
        path: "../contracts/RandomConsumer.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}