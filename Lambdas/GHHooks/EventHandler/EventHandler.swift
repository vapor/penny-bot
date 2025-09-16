import DiscordBM
import GitHubAPI

struct EventHandler: Sendable {
    let context: HandlerContext

    func handle() async throws {
        switch context.eventName {
        case .issues:
            try await IssueHandler(context: context).handle()
        case .pull_request:
            try await PRHandler(context: context).handle()
        case .release:
            try await ReleaseReporter(context: context).handle()
        case .push:
            try await withThrowingAccumulatingVoidTaskGroup(tasks: [
                { try await DocsIssuer(context: context).handle() },
                { try await PRCoinGiver(context: context).handle() },
            ])
        case .ping:
            try await onPing()
        case .sponsorship:
            try await onSponsorship()
        case .pull_request_review,
            .projects_v2_item,
            .project_card,
            .label,
            .installation_repositories,
            .security_advisory:
            break
        default:
            try await onDefault()
        }
    }

    func onPing() async throws {
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.botLogs.id,
            payload: .init(embeds: [
                .init(
                    title: "Ping events should not reach here",
                    description: """
                        Ping events must be handled immediately, even before any body-decoding happens.
                        Action: \(context.event.action ?? "<null>")
                        Repo: \(context.event.repository?.name ?? "<null>")
                        """,
                    color: .red
                )
            ])
        ).guardSuccess()
    }

    func onSponsorship() async throws {
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.botLogs.id,
            payload: .init(embeds: [
                .init(
                    title: "Got Sponsorship payload. Check the logs!",
                    description: """
                        Action: \(context.event.action ?? "<null>")
                        Repo: \(context.event.repository?.name ?? "<null>")
                        """,
                    color: .yellow
                )
            ])
        ).guardSuccess()
    }

    func onDefault() async throws {
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.botLogs.id,
            payload: .init(embeds: [
                .init(
                    title: "Received UNHANDLED event \(context.eventName)",
                    description: """
                        Action: \(context.event.action ?? "<null>")
                        Repo: \(context.event.repository?.name ?? "<null>")
                        """,
                    color: .red
                )
            ])
        ).guardSuccess()
    }
}
