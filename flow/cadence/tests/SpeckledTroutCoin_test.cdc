import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "SpeckledTroutCoin",
        path: "../contracts/SpeckledTroutCoin.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}