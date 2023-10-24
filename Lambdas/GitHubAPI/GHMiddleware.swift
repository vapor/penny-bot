#if canImport(Darwin)
import Foundation
#else
@preconcurrency import Foundation
#endif
import OpenAPIRuntime
import Atomics
import Logging
import HTTPTypes
import NIOCore
import OpenAPIAsyncHTTPClient

/// Adds some headers to all requests.
struct GHMiddleware: ClientMiddleware {
    let authorization: AuthorizationHeader
    let logger: Logger

    private static let allocator = ByteBufferAllocator()

    static let idGenerator = ManagedAtomic(UInt(0))

    init(authorization: AuthorizationHeader, logger: Logger) {
        self.authorization = authorization
        self.logger = logger
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields.reserveCapacity(4)

        request.headerFields.addOrReplace(
            name: .accept,
            value: "application/vnd.github.raw+json"
        )
        request.headerFields.addOrReplace(
            name: .xGitHubAPIVersion,
            value: "2022-11-28"
        )
        request.headerFields.addOrReplace(
            name: .userAgent,
            value: "Penny/1.0.0 (https://github.com/vapor/penny-bot)"
        )

        return try await intercept(
            &request,
            body: body,
            baseURL: baseURL,
            operationID: operationID,
            isRetry: false,
            next: next
        )
    }

    private func intercept(
        _ request: inout HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        isRetry: Bool,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if let authHeader = try await authorization.makeHeader(isRetry: isRetry) {
            request.headerFields.addOrReplace(name: .authorization, value: authHeader)
        }

        let requestID = Self.idGenerator.loadThenWrappingIncrement(ordering: .relaxed)

        logger.debug("Will send request to GitHub", metadata: [
            "request": "\(request)",
            "baseURL": .stringConvertible(baseURL),
            "operationID": .string(operationID),
            "requestID": .stringConvertible(requestID),
        ])

        do {
            let (response, body) = try await next(request, body, baseURL)
            let collectedBody = try await body?.collect(upTo: 1 << 28, using: Self.allocator)

            logger.debug("Got response from GitHub", metadata: [
                "response": .string(response.debugDescription),
                "requestID": .stringConvertible(requestID),
            ])

            /// If this is not _the_ retry,
            /// and if the authorization is retriable,
            /// and if the response status is `401 Unauthorized`,
            /// then retry the request with a force-refreshed token.
            if !isRetry,
               authorization.isRetriable,
               response.status == .unauthorized {
                logger.warning("Got 401 from GitHub. Will retry the request with a fresh token")
                return try await intercept(
                    &request,
                    body: body,
                    baseURL: baseURL,
                    operationID: operationID,
                    isRetry: true,
                    next: next
                )
            } else {
                return (response, collectedBody.map { HTTPBody($0.readableBytesView) })
            }
        } catch {
            logger.error("Got error from GitHub", metadata: [
                "error": "\(error)",
                "requestID": .stringConvertible(requestID),
            ])

            throw error
        }
    }
}

private extension HTTPFields {
    mutating func addOrReplace(name: HTTPField.Name, value: String) {
        let header = HTTPField(name: name, value: value)
        if let existingIdx = self.firstIndex(
            where: { $0.name == name }
        ) {
            self[existingIdx] = header
        } else {
            self.append(header)
        }
    }
}

private extension HTTPField.Name {
    static let xGitHubAPIVersion = Self("X-GitHub-Api-Version")!
}
