import DiscordBM

struct EventHandler {
    let client: any DiscordClient
    let eventName: GHEvent.Kind
    let event: GHEvent

    func handle() async throws {
        /// This is for testing purposes for now:
        switch eventName {
        case .issues:
            try await onIssue()
        case .pull_request:
            try await onPullRequest()
        case .ping:
            try await onPing()
        default:
            try await onDefault()
        }
    }

    func onPullRequest() async throws {
        let action = event.action.map({ PullRequest.Action(rawValue: $0) })
        guard action == .opened else { return }

        let pr = try event.pullRequest.requireValue()

        let number = try event.number.requireValue()

        let creatorName = pr.user.login
        let creatorLink = pr.user.htmlURL

        let prLink = pr.htmlURL

        let repositoryLink = event.repository.htmlURL
        let repositoryName = event.repository.fullName

        try await client.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(
                embeds: [
                    .init(
                        title: String("PR #\(number): \(pr.title)".prefix(256)),
                        description: """
                        In [\(repositoryName)](\(repositoryLink))
                        Opened by **[\(creatorName)](\(creatorLink))**
                        """,
                        color: .green
                    )
                ],
                components: [[
                    .button(.init(label: "Open", url: prLink))
                ]]
            )
        ).guardSuccess()
    }

    func onIssue() async throws {
        let action = event.action.map({ Issue.Action(rawValue: $0) })
        guard action == .opened else { return }

        let issue = try event.issue.requireValue()

        let number = try event.number.requireValue()

        let user = try issue.user.requireValue()
        let creatorName = user.login
        let creatorLink = user.htmlURL

        let issueLink = issue.htmlURL

        let repositoryLink = event.repository.htmlURL
        let repositoryName = event.repository.fullName

        try await client.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(
                embeds: [
                    .init(
                        title: String("Issue #\(number): \(issue.title)".prefix(256)),
                        description: """
                        In [\(repositoryName)](\(repositoryLink))
                        Opened by **[\(creatorName)](\(creatorLink))**
                        """,
                        color: .yellow
                    )
                ],
                components: [[
                    .button(.init(label: "Open", url: issueLink))
                ]]
            )
        ).guardSuccess()
    }

    func onPing() async throws {
        try await client.createMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(embeds: [.init(
                title: "Ping events should not reach here",
                description: """
                Ping events should be handled immediately, even before any body-decoding happens.
                Action: \(event.action ?? "null")
                Repo: \(event.repository.name)
                """,
                color: .red
            )])
        ).guardSuccess()
    }

    func onDefault() async throws {
        try await client.createMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(embeds: [.init(
                title: "Received UNHANDLED event \(eventName)",
                description: """
                    Action: \(event.action ?? "null")
                    Repo: \(event.repository.name)
                    """,
                color: .red
            )])
        ).guardSuccess()
    }
}
