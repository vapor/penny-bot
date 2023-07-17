import struct DiscordModels.Secret
import SotoCore
import SotoSecretsManager
import Logging
import Foundation

actor SecretsRetriever {
    private let secretsManager: SecretsManager
    /// `[arnEnvVarKey: secret]`
    private var cache: [String: Secret] = [:]
    let logger: Logger

    private let lock = ActorLock()

    init(awsClient: AWSClient, logger: Logger) {
        self.secretsManager = SecretsManager(client: awsClient)
        self.logger = logger
    }

    func getSecret(arnEnvVarKey: String) async throws -> Secret {
        return try await lock.withLock {
            if let cached = await getCache(key: arnEnvVarKey) {
                return cached
            } else {
                let value = try await self.getSecretFromAWS(arnEnvVarKey: arnEnvVarKey)
                await self.setCache(key: arnEnvVarKey, value: value)
                return value
            }
        }
    }

    /// Gets a secret directly from AWS.
    private func getSecretFromAWS(arnEnvVarKey: String) async throws -> Secret {
        guard let arn = ProcessInfo.processInfo.environment[arnEnvVarKey] else {
            throw OAuthLambdaError.envVarNotFound(name: arnEnvVarKey)
        }
        logger.trace("Retrieving secret from AWS", metadata: [
            "arnEnvVarKey": .string(arnEnvVarKey)
        ])
        let secret = try await secretsManager.getSecretValue(
            .init(secretId: arn),
            logger: logger
        )
        guard let secret = secret.secretString else {
            throw OAuthLambdaError.secretNotFound(arn: arn)
        }
        return Secret(secret)
    }

    /// Sets a value in the cache.
    private func setCache(key: String, value: Secret) {
        self.cache[key] = value
    }

    /// Gets a value from the cache.
    private func getCache(key: String) -> Secret? {
        self.cache[key]
    }
}
