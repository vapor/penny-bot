import Rendering

extension RenderClient {
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

    func ticketReport(title: String, body: String) async throws -> String {
        try await render(
            path: "ticket_report.description",
            context: [
                "title": .string(title),
                "body": .string(body),
            ]
        )
    }
}

