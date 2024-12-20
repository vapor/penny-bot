import AsyncHTTPClient
import Logging

import struct NIOCore.TimeAmount

extension Client {
    package static func makeForGitHub(
        httpClient: HTTPClient,
        authorization: AuthorizationHeader,
        timeout: TimeAmount = .seconds(5),
        logger: Logger
    ) throws -> Client {
        let middleware = GHMiddleware(
            authorization: authorization,
            logger: logger
        )
        let transport = AsyncHTTPClientTransport(
            configuration: .init(
                client: httpClient,
                timeout: timeout
            )
        )
        return Client(
            serverURL: try Servers.Server1.url(),
            transport: transport,
            middlewares: [middleware]
        )
    }
}
