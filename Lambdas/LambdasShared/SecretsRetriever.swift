import SotoCore
import SotoSecretsManager
import Logging
import Foundation

public actor SecretsRetriever {
    private let secretsManager: SecretsManager
    /// `[arnEnvVarKey: secret]`
    private var cache: [String: String] = [:]
    let logger: Logger

    private let queue = SerialProcessor()

    public init(awsClient: AWSClient, logger: Logger) {
        self.secretsManager = SecretsManager(client: awsClient)
        self.logger = logger
    }

    public func getSecret(arnEnvVarKey: String) async throws -> String {
        return try await queue.process {
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
    private func getSecretFromAWS(arnEnvVarKey: String) async throws -> String {
        guard let arn = ProcessInfo.processInfo.environment[arnEnvVarKey] else {
            throw Errors.envVarNotFound(name: arnEnvVarKey)
        }
        logger.trace("Retrieving secret from AWS", metadata: [
            "arnEnvVarKey": .string(arnEnvVarKey)
        ])
        let secret = try await secretsManager.getSecretValue(
            .init(secretId: arn),
            logger: logger
        )
        guard let secret = secret.secretString else {
            throw Errors.secretNotFound(arn: arn)
        }
        return secret
    }

    /// Sets a value in the cache.
    private func setCache(key: String, value: String) {
        self.cache[key] = value
    }

    /// Gets a value from the cache.
    private func getCache(key: String) -> String? {
        self.cache[key]
    }
}
