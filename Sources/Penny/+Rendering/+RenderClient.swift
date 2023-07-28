import Rendering

extension RenderClient {
    func autoPingsHelp(context: AutoPingsContext) async throws -> String {
        try await self.render(path: "auto_pings.help", context: context)
    }
}
