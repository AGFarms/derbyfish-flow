import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "FishCardNFT",
        path: "../contracts/FishCardNFT.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}