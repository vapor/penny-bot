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

        let number = try event.number.requireValue()
        let repoName = event.repository.name
        let orgName = event.organization.login
        let linkSuffix = "\(orgName)/\(repoName)/pull/\(number)"

        let prLink = "https://github.com/\(linkSuffix)"

        let senderName = event.sender.login
        let senderLink = "https://github.com/\(senderName)"

        let ogImage = "https://opengraph.githubassets.com/1/\(linkSuffix)"

        try await client.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(
                embeds: [
                    .init(
                        title: "New Pull Request",
                        description: """
                        Created by **[\(senderName)](\(senderLink))**
                        """,
                        color: .green,
                        image: .init(url: .exact(ogImage))
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
        /// FIXME: testing
//        guard action == .opened else { return }

        let number = try event.number.requireValue()
        let repoName = event.repository.name
        let orgName = event.organization.login
        let linkSuffix = "\(orgName)/\(repoName)/issues/\(number)"

        let issueLink = "https://github.com/\(linkSuffix)"

        let senderName = event.sender.login
        let senderLink = "https://github.com/\(senderName)"

        let ogImage = "https://opengraph.githubassets.com/1/\(linkSuffix)"

        try await client.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(
                embeds: [
                    .init(
                        title: "New Issue",
                        description: """
                        Created by **[\(senderName)](\(senderLink))**
                        """,
                        color: .yellow,
                        image: .init(url: .exact(ogImage))
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
