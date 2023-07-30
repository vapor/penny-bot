import LeafKit
import NIO
import Foundation

extension LeafRenderer {
    static func forPenny(on eventLoop: any EventLoop) throws -> LeafRenderer {
        try LeafRenderer(path: "Sources/Penny", on: eventLoop)
    }
}
