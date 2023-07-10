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

    private var isLocked = false
    private var lockWaiters: [CheckedContinuation<Void, Never>] = []

    init(awsClient: AWSClient, logger: Logger) {
        self.secretsManager = SecretsManager(client: awsClient)
        self.logger = logger
    }

    func getSecret(arnEnvVarKey: String) async throws -> Secret {
        return try await withLock {
            if let cached = getCache(key: arnEnvVarKey) {
                return cached
            } else {
                let value = try await self.getSecretFromAWS(arnEnvVarKey: arnEnvVarKey)
                self.setCache(key: arnEnvVarKey, value: value)
                return value
            }
        }
    }

    private func getSecretFromAWS(arnEnvVarKey: String) async throws -> Secret {
        guard let arn = ProcessInfo.processInfo.environment[arnEnvVarKey] else {
            throw Errors.envVarNotFound(name: arnEnvVarKey)
        }
        let secret = try await secretsManager.getSecretValue(
            .init(secretId: arn),
            logger: logger
        )
        guard let secret = secret.secretString else {
            throw Errors.secretNotFound(arn: arn)
        }
        return Secret(secret)
    }

    private func withLock<T>(block: () async throws -> T) async rethrows -> T {
        while isLocked {
            await withCheckedContinuation { continuation in
                lockWaiters.append(continuation)
            }
        }

        isLocked = true
        defer {
            isLocked = false
            lockWaiters.popLast()?.resume()
        }

        return try await block()
    }

    private func setCache(key: String, value: Secret) {
        self.cache[key] = value
    }

    private func getCache(key: String) -> Secret? {
        self.cache[key]
    }
}
