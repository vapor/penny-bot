@testable import LambdasShared

struct FakeSecretsRetriever: GenericSecretsRetriever {
    func getSecret(arnEnvVarKey: String) async throws -> String {
        "test-secret"
    }
}
