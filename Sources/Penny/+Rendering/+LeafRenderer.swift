import LeafKit
import NIO
import AsyncHTTPClient
import Logging
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
