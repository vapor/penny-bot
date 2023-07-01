import SotoCore
import SotoSecretsManager
import Logging
import Foundation

struct SecretsRetriever {
    private let secretsManager: SecretsManager
    let logger: Logger

    init(awsClient: AWSClient, logger: Logger) {
        self.secretsManager = SecretsManager(client: awsClient)
        self.logger = logger
    }

    func getSecret(arnEnvVarKey: String) async throws -> String {
        guard let arn = ProcessInfo.processInfo.environment[arnEnvVarKey] else {
            throw OAuthLambdaError.envVarNotFound(name: arnEnvVarKey)
        }
        let secret = try await secretsManager.getSecretValue(
            .init(secretId: arn),
            logger: logger
        )
        guard let secret = secret.secretString else {
            throw OAuthLambdaError.secretNotFound(arn: arn)
        }
        return secret
    }
}
