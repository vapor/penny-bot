import Atomics
import Logging
import OpenAPIRuntime

#if canImport(Darwin)
import Foundation
#else
@preconcurrency import Foundation
#endif

/// Adds some headers to all requests.
struct GHMiddleware: ClientMiddleware {
    let authorization: AuthorizationHeader
    let logger: Logger

    static let idGenerator = ManagedAtomic(UInt(0))

    init(authorization: AuthorizationHeader, logger: Logger) {
        self.authorization = authorization
        self.logger = logger
    }

    /// Intercepts, modifies and makes the request and
    /// retries it if it seems like a invalid-auth-header problem.
    func intercept(
        _ request: Request,
        baseURL: URL,
        operationID: String,
        next: @Sendable (Request, URL) async throws -> Response
    ) async throws -> Response {
        var request = request
        request.headerFields.reserveCapacity(4)

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
            value: "Penny/1.0.0 (https://github.com/vapor/penny-bot)"
        )

        return try await intercept(
            &request,
            baseURL: baseURL,
            operationID: operationID,
            isRetry: false,
            next: next
        )
    }

    private func intercept(
        _ request: inout Request,
        baseURL: URL,
        operationID: String,
        isRetry: Bool,
        next: @Sendable (Request, URL) async throws -> Response
    ) async throws -> Response {
        if let authHeader = try await authorization.makeHeader(isRetry: isRetry) {
            request.headerFields.addOrReplace(name: "Authorization", value: authHeader)
        }

        let requestID = Self.idGenerator.loadThenWrappingIncrement(ordering: .relaxed)

        logger.debug(
            "Will send request to GitHub",
            metadata: [
                "request": "\(request)",
                "baseURL": .stringConvertible(baseURL),
                "operationID": .string(operationID),
                "requestID": .stringConvertible(requestID),
            ]
        )

        do {
            let response = try await next(request, baseURL)

            logger.debug(
                "Got response from GitHub",
                metadata: [
                    "response": "\(response.fullDescription)",
                    "requestID": .stringConvertible(requestID),
                ]
            )

            /// If this is not _the_ retry,
            /// and if the authorization is retriable,
            /// and if the response status is `401 Unauthorized`,
            /// then retry the request with a force-refreshed token.
            if !isRetry,
                authorization.isRetriable,
                response.statusCode == 401
            {
                logger.warning("Got 401 from GitHub. Will retry the request with a fresh token")
                return try await intercept(
                    &request,
                    baseURL: baseURL,
                    operationID: operationID,
                    isRetry: true,
                    next: next
                )
            } else {
                return response
            }
        } catch {
            logger.error(
                "Got error from GitHub",
                metadata: [
                    "error": "\(error)",
                    "requestID": .stringConvertible(requestID),
                ]
            )

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
        "Response(" + "status: \(statusCode), " + "headers: \(headerFields.description), "
            + "body: \(String(decoding: body, as: UTF8.self))" + ")"
    }
}
