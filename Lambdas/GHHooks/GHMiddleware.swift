import OpenAPIRuntime
import Atomics
import Logging
import Foundation
import struct DiscordModels.Secret

/// Adds some headers to all requests.
struct GHMiddleware: ClientMiddleware {

    enum Authorization {
        case bearer(String)
        /// FIXME: After implementation check if this enum is needed or not.
        case basic

        func getHeader(secretsRetriever: SecretsRetriever) async throws -> String {
            switch self {
            case let .bearer(token):
                return "Bearer \(token)"
            case .basic:
                let token = try await secretsRetriever.getSecret(arnEnvVarKey: "GH_TOKEN_ARN")
                let username = "VaporBot"
                let basicCredentials = Data("\(username):\(token.value)".utf8).base64EncodedString()
                return "Basic \(basicCredentials)"
            }
        }
    }

    let secretsRetriever: SecretsRetriever
    let authorization: Authorization
    let logger: Logger

    static let idGenerator = ManagedAtomic(UInt(0))

    init(secretsRetriever: SecretsRetriever, authorization: Authorization, logger: Logger) {
        self.secretsRetriever = secretsRetriever
        self.authorization = authorization
        self.logger = logger
    }

    func intercept(
        _ request: Request,
        baseURL: URL,
        operationID: String,
        next: @Sendable (Request, URL) async throws -> Response
    ) async throws -> Response {
        var request = request
        request.headerFields.reserveCapacity(4)

        let authHeader = try await authorization.getHeader(secretsRetriever: secretsRetriever)
        request.headerFields.addOrReplace(
            name: "Authorization",
            value: authHeader
        )
        request.headerFields.addOrReplace(
            name: "Accept",
            value: "application/vnd.github.raw+json"
        )
        request.headerFields.addOrReplace(
            name: "X-GitHub-Api-Version",
            value: "2022-11-28"
        )
        request.headerFields.addOrReplace(
            name: "User-Agent",
            value: "Penny - 1.0.0 (https://github.com/vapor/penny-bot)"
        )

        let requestID = Self.idGenerator.loadThenWrappingIncrement(ordering: .relaxed)

        logger.debug("Will send request to Github", metadata: [
            "request": "\(request)",
            "baseURL": .stringConvertible(baseURL),
            "operationID": .string(operationID),
            "requestID": .stringConvertible(requestID),
        ])

        do {
            let response = try await next(request, baseURL)
            
            logger.debug("Got response from Github", metadata: [
                "response": "\(response.fullDescription)",
                "requestID": .stringConvertible(requestID),
            ])

            return response
        } catch {
            logger.error("Got error from Github", metadata: [
                "error": "\(error)",
                "requestID": .stringConvertible(requestID),
            ])

            throw error
        }
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
