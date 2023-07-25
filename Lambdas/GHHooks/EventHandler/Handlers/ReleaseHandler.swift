import GitHubAPI
import DiscordBM

struct ReleaseHandler {
    let context: HandlerContext
    let release: Release

    init(context: HandlerContext) throws {
        self.context = context
        self.release = try context.event.release.requireValue()
    }

    func handle() async throws {
        let /*action*/ _ = try context.event.action
            .flatMap({ Release.Action(rawValue: $0) })
            .requireValue()
        let /*release*/ _ = try context.event.release.requireValue()
        /// Does nothing for now
    }
}
