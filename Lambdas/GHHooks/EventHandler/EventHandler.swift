import DiscordBM

struct EventHandler {
    let context: HandlerContext

    func handle() async throws {
        switch context.eventName {
        case .issues:
            try await IssueHandler(context: context).handle()
        case .pull_request:
            try await PRHandler(context: context).handle()
        case .ping:
            try await onPing()
        default:
            try await onDefault()
        }
    }

    func onPing() async throws {
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(embeds: [.init(
                title: "Ping events should not reach here",
                description: """
                Ping events must be handled immediately, even before any body-decoding happens.
                Action: \(context.event.action ?? "null")
                Repo: \(context.event.repository.name)
                """,
                color: .red
            )])
        ).guardSuccess()
    }

    func onDefault() async throws {
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(embeds: [.init(
                title: "Received UNHANDLED event \(context.eventName)",
                description: """
                Action: \(context.event.action ?? "null")
                Repo: \(context.event.repository.name)
                """,
                color: .red
            )])
        ).guardSuccess()
    }
}

extension String {
    func unicodesPrefix(_ maxLength: Int) -> String {
        String(self.unicodeScalars.prefix(maxLength))
    }
}
