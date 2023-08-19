import SotoCore
import SotoSecretsManager
import Logging
import Shared
import Foundation

public actor SecretsRetriever {

    enum Errors: Error, CustomStringConvertible {
        case secretNotFound(arn: String)

        var description: String {
            switch self {
            case let .secretNotFound(arn):
                return "secretNotFound(arn: \(arn))"
            }
        }
    }

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
        logger.trace("Get secret start", metadata: [
            "arnEnvVarKey": .string(arnEnvVarKey)
        ])
        let secret = try await queue.process(queueKey: arnEnvVarKey) {
            if let cached = await getCache(key: arnEnvVarKey) {
                logger.debug("Will return cached secret", metadata: [
                    "arnEnvVarKey": .string(arnEnvVarKey)
                ])
                return cached
            } else {
                let value = try await self.getSecretFromAWS(arnEnvVarKey: arnEnvVarKey)
                await self.setCache(key: arnEnvVarKey, value: value)
                return value
            }
        }
        logger.trace("Get secret done", metadata: [
            "arnEnvVarKey": .string(arnEnvVarKey)
        ])
        return secret
    }

    /// Gets a secret directly from AWS.
    private func getSecretFromAWS(arnEnvVarKey: String) async throws -> String {
        logger.trace("Retrieving secret from AWS", metadata: [
            "arnEnvVarKey": .string(arnEnvVarKey)
        ])
        let arn = try requireEnvVar(arnEnvVarKey)
        let secret = try await secretsManager.getSecretValue(
            .init(secretId: arn),
            logger: logger
        )
        guard let secret = secret.secretString else {
            throw Errors.secretNotFound(arn: arn)
        }
        logger.trace("Got secret from AWS", metadata: [
            "arnEnvVarKey": .string(arnEnvVarKey)
        ])
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
