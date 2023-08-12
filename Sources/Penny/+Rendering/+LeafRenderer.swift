import AsyncHTTPClient
import Foundation
import LeafKit
import Logging
import NIO

extension LeafRenderer {
    static func forPenny(
        httpClient: HTTPClient,
        logger: Logger,
        on eventLoop: any EventLoop
    ) throws -> LeafRenderer {
        try LeafRenderer(
            subDirectory: "Penny",
            httpClient: httpClient,
            logger: logger,
            on: eventLoop
        )
    }
}
