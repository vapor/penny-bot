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
        /// FIXME: testing
//        guard action == .opened else { return }
//        let pr = try event.pullRequest.requireValue()

        let number = try event.number.requireValue()
        let repoName = event.repository.name
        let orgName = event.organization.login
        let prLink = "https://github.com/\(orgName)/\(repoName)/pull/\(number)"

        let senderName = event.sender.login
        let senderLink = "https://github.com/\(senderName)"

        try await client.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(
                embeds: [
                    .init(
                        title: "New PR",
                        description: """
                        Created by **[\(senderName)](\(senderLink))**
                        """,
                        color: .green
                    ),
                    .init(url: prLink)
                ],
                components: [[
                    .button(.init(label: "Open PR", url: prLink))
                ]]
            )
        ).guardSuccess()
    }

    func onIssue() async throws {
        let action = event.action.map({ Issue.Action(rawValue: $0) })
        /// FIXME: testing
//        guard action == .opened else { return }
//        let issue = try event.issue.requireValue()

        let number = try event.number.requireValue()
        let repoName = event.repository.name
        let orgName = event.organization.login
        let issueLink = "https://github.com/\(orgName)/\(repoName)/issues/\(number)"

        let senderName = event.sender.login
        let senderLink = "https://github.com/\(senderName)"

        try await client.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(
                embeds: [
                    .init(
                        title: "New Issue",
                        description: """
                        Created by **[\(senderName)](\(senderLink))**
                        """,
                        color: .yellow
                    ),
                    .init(url: issueLink)
                ],
                components: [[
                    .button(.init(label: "Open Issue", url: issueLink))
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
