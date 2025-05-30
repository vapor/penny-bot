@preconcurrency import LeafKit
import NIOCore

package struct RenderClient: Sendable {
    let renderer: LeafRenderer
    let encoder = LeafEncoder()

    package init(renderer: LeafRenderer) {
        self.renderer = renderer
    }

    package func render(path: String, context: [String: LeafData]) async throws -> String {
        let buffer = try await renderer.render(path: "\(path).leaf", context: context).get()
        return String(buffer: buffer)
    }

    package func render<Context: Encodable>(
        path: String,
        context: Context
    ) async throws -> String {
        let data = try LeafEncoder.encode(context)
        return try await self.render(path: path, context: data)
    }
}
