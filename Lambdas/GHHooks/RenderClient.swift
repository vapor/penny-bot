import LeafKit

struct RenderClient {
    let renderer: LeafRenderer
}

extension RenderClient {
    func translationNeededTitle(number: Int) async throws -> String {
        try await renderer.render(
            path: "translation_needed.title",
            context: ["number": .int(number)]
        )
    }

    func translationNeededDescription(number: Int) async throws -> String {
        try await renderer.render(
            path: "translation_needed.description",
            context: ["number": .int(number)]
        )
    }
}
