import OpenAPIRuntime
import Logging
import Foundation
import struct DiscordModels.Secret

/// Adds some headers to all requests.
/// Loads the GH token lazily to avoid additional secrets-manager costs.
actor GHLazyMiddleware: ClientMiddleware {

    private let secretsRetriever: SecretsRetriever
    private let logger: Logger

    private var idGenerator = 0

    private var isLoading = false
    private var loadWaiters: [CheckedContinuation<Void, Never>] = []

    init(secretsRetriever: SecretsRetriever, logger: Logger) {
        self.secretsRetriever = secretsRetriever
        self.logger = logger
    }

    func intercept(
        _ request: Request,
        baseURL: URL,
        operationID: String,
        next: @Sendable (Request, URL) async throws -> Response
    ) async throws -> Response {
        var request = request

        let token = try await secretsRetriever.getSecret(arnEnvVarKey: "GH_TOKEN_ARN")
        request.headerFields.addOrReplace(
            name: "Authorization",
            /// Token loaded so can force-unwrap.
            value: "Bearer \(token.value)"
        )
        request.headerFields.addOrReplace(
            name: "Accept",
            value: "application/vnd.github.raw+json"
        )
        request.headerFields.addOrReplace(
            name: "X-GitHub-Api-Version",
            value: "2022-11-28"
        )

        self.idGenerator += 1
        let requestID = idGenerator

        logger.debug("Will send request to Github", metadata: [
            "request": "\(request)",
            "baseURL": .stringConvertible(baseURL),
            "operationID": .string(operationID),
            "requestID": .stringConvertible(requestID),
        ])

        let response = try await next(request, baseURL)

        logger.debug("Got response from Github", metadata: [
            "response": "\(response.fullDescription)",
            "requestID": .stringConvertible(requestID),
        ])

        return response
    }
}

private extension [HeaderField] {
    mutating func addOrReplace(name: String, value: String) {
        let header = HeaderField(name: name, value: value)
        if let existingIdx = self.firstIndex(
            where: { $0.name.caseInsensitiveCompare(name).rawValue == 0 }
        ) {
            self[existingIdx] = header
        } else {
            self.append(header)
        }
    }
}

private extension Response {
    var fullDescription: String {
        "Response(" +
        "status: \(statusCode), " +
        "headers: \(headerFields.description), " +
        "body: \(String(decoding: body, as: UTF8.self))" +
        ")"
    }
}
