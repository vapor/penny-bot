import LeafKit
import NIO
import Foundation

extension LeafRenderer {
    static func forPenny(on eventLoop: any EventLoop) throws -> LeafRenderer {
        try LeafRenderer(subDirectory: "Penny", on: eventLoop)
    }
}
