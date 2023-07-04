import DiscordBM

struct EventHandler {
    let client: any DiscordClient
    let eventName: GHEvent.Kind
    let event: GHEvent

    func handle() async throws {
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

        let pr = try event.pull_request.requireValue()

        let number = try event.number.requireValue()

        let creatorName = pr.user.login
        let creatorLink = pr.user.html_url

        let prLink = pr.html_url

        let repo = event.repository

        let body = pr.body == nil ? "" : "\n\n>>> \(pr.body!)".unicodesPrefix(264)

        let description = """
        ## \(pr.title)

        ### By **[\(creatorName)](\(creatorLink))**
        \(body)
        """

        try await client.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(embeds: [.init(
                title: String("\(repo.name) PR #\(number)".unicodesPrefix(256)),
                description: description,
                url: prLink,
                color: .green
            )])
        ).guardSuccess()
    }

    func onIssue() async throws {
        let action = event.action.map({ Issue.Action(rawValue: $0) })
        guard action == .opened else { return }

        let issue = try event.issue.requireValue()

        let number = try event.issue.requireValue().number

        let user = issue.user
        let creatorName = user.login
        let creatorLink = user.html_url

        let issueLink = issue.html_url

        let repo = event.repository

        let body = issue.body == nil ? "" : "\n\n>>> \(issue.body!)".unicodesPrefix(264)

        let description = """
        ## \(issue.title)

        ### By **[\(creatorName)](\(creatorLink))**
        \(body)
        """

        try await client.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(embeds: [.init(
                title: String("\(repo.name) Issue #\(number)".unicodesPrefix(256)),
                description: description,
                url: issueLink,
                color: .yellow
            )])
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

extension String {
    func unicodesPrefix(_ maxLength: Int) -> String {
        String(self.unicodeScalars.prefix(maxLength))
    }
}
