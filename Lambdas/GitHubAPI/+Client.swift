import AsyncHTTPClient
import Logging

extension Client {
    public static func makeForGitHub(
        httpClient: HTTPClient,
        authorization: GHMiddleware.Authorization,
        logger: Logger
    ) throws -> Client {
        let middleware = GHMiddleware(
            authorization: authorization,
            logger: logger
        )
        let transport = AsyncHTTPClientTransport(configuration: .init(
            client: httpClient,
            timeout: .seconds(3)
        ))
        return Client(
            serverURL: try Servers.server1(),
            transport: transport,
            middlewares: [middleware]
        )
    }
}
