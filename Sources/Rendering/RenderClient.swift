@preconcurrency import LeafKit

public struct RenderClient: Sendable {
    let renderer: LeafRenderer
    let encoder = LeafEncoder()

    public init(renderer: LeafRenderer) {
        self.renderer = renderer
    }

    public func render(path: String, context: [String: LeafData]) async throws -> String {
        let buffer = try await renderer.render(path: "\(path).leaf", context: context).get()
        return String(buffer: buffer)
    }

    public func render<Context: Encodable>(
        path: String,
        context: Context
    ) async throws -> String {
        let data = try LeafEncoder.encode(context)
        return try await self.render(path: path, context: data)
    }
}
