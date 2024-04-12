import LeafKit
import NIO
import AsyncHTTPClient
import Logging
import Foundation

extension LeafRenderer {
    static func forPenny(logger: Logger) throws -> LeafRenderer {
        try LeafRenderer(
            subDirectory: "Penny",
            logger: logger
        )
    }
}
