import LeafKit
import NIO
import AsyncHTTPClient
import Logging
import Foundation

extension LeafRenderer {
    static func forPenny(
        httpClient: HTTPClient,
        logger: Logger,
        on eventLoop: any EventLoop
    ) throws -> LeafRenderer {
        try LeafRenderer(
            path: "Sources/Penny",
            httpClient: httpClient,
            logger: logger,
            on: eventLoop
        )
    }
}
