import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "Fishdex",
        path: "../contracts/Fishdex.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}