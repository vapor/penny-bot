package protocol GenericSecretsRetriever: Sendable {
    func getSecret(arnEnvVarKey: String) async throws -> String
}
