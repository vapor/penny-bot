import LeafKit

struct RenderClient {
    let renderer: LeafRenderer
    private let encoder = LeafEncoder()

    func render(path: String, context: [String: LeafData]) async throws -> String {
        let buffer = try await renderer.render(path: "\(path).leaf", context: context).get()
        return String(buffer: buffer)
    }

    func render<Context: Encodable>(
        path: String,
        context: Context
    ) async throws -> String {
        let data = try LeafEncoder.encode(context)
        return try await self.render(path: path, context: data)
    }
}

extension RenderClient {
    func translationNeededTitle(number: Int) async throws -> String {
        try await render(
            path: "translation_needed.title",
            context: ["number": .int(number)]
        )
    }

    func translationNeededDescription(number: Int) async throws -> String {
        try await render(
            path: "translation_needed.description",
            context: ["number": .int(number)]
        )
    }

    func newReleaseDescription(context: NewReleaseContext) async throws -> String {
        try await render(
            path: "new_release.description",
            context: context
        )
    }
}

