import DiscordBM
import GitHubAPI
import Dependencies

struct EventHandler: Sendable {

    func handle() async throws {
        @Dependency(\.eventName) var eventName

        switch eventName {
        case .issues:
            try await IssueHandler(context: context).handle()
        case .pull_request:
            try await PRHandler(context: context).handle()
        case .release:
            try await ReleaseReporter(context: context).handle()
        case .push:
            try await withThrowingAccumulatingVoidTaskGroup(tasks: [
                { try await DocsIssuer(context: context).handle() },
                { try await PRCoinGiver(context: context).handle() }
            ])
        case .ping:
            try await onPing()
        case .sponsorship:
            try await onSponsorship()
        case .pull_request_review, .projects_v2_item, .project_card, .label, .installation_repositories:
            break
        default:
            try await onDefault()
        }
    }

    func onPing() async throws {
        @Dependency(\.discordClient) var discordClient
        @Dependency(\.event) var event

        try await discordClient.createMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(embeds: [.init(
                title: "Ping events should not reach here",
                description: """
                Ping events must be handled immediately, even before any body-decoding happens.
                Action: \(event.action ?? "<null>")
                Repo: \(event.repository?.name ?? "<null>")
                """,
                color: .red
            )])
        ).guardSuccess()
    }

    func onSponsorship() async throws {
        @Dependency(\.discordClient) var discordClient
        @Dependency(\.event) var event

        try await discordClient.createMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(embeds: [.init(
                title: "Got Sponsorship payload. Check the logs!",
                description: """
                Action: \(event.action ?? "<null>")
                Repo: \(event.repository?.name ?? "<null>")
                """,
                color: .yellow
            )])
        ).guardSuccess()
    }

    func onDefault() async throws {
        @Dependency(\.discordClient) var discordClient
        @Dependency(\.event) var event
        @Dependency(\.eventName) var eventName

        try await discordClient.createMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(embeds: [.init(
                title: "Received UNHANDLED event \(eventName)",
                description: """
                Action: \(event.action ?? "<null>")
                Repo: \(event.repository?.name ?? "<null>")
                """,
                color: .red
            )])
        ).guardSuccess()
    }
}
