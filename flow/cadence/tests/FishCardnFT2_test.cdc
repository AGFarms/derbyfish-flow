import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "FishCardnFT2",
        path: "../contracts/FishCardnFT2.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}