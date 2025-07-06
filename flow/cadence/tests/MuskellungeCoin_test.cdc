import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "MuskellungeCoin",
        path: "../contracts/MuskellungeCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}