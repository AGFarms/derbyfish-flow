transaction {
    prepare(signer: AuthAccount) {
        let code = loadCode("UnverifiedFishScan")
        signer.contracts.add(name: "UnverifiedFishScan", code: code)
    }
}