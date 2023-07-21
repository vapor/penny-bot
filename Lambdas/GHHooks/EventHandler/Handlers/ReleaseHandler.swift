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
        let action = try context.event.action
            .flatMap({ Release.Action(rawValue: $0) })
            .requireValue()
        let release = try context.event.release.requireValue()
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(
                embeds: [.init(
                    title: "Got sample release. Check the logs now.",
                    description: """
                    Action: \(action)
                    URL: \(release.html_url)
                    """,
                    color: .yellow
                )])
        ).guardSuccess()
    }
}
