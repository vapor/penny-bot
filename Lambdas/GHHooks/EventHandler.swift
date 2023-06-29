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

        let repo = event.repository
        let repoName = repo.owner.login == "vapor" ? repo.name : repo.fullName

        let body = pr.body == nil ? "" : "\n\n>>> \(pr.body!)".prefix(264)

        let title = "\(repoName) #\(number): \(pr.title)"
        let descriptionHeader = "### PR opened by **[\(creatorName)](\(creatorLink))**"

        try await client.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(embeds: [.init(
                title: String(title.prefix(256)),
                description: descriptionHeader + body,
                url: prLink,
                color: .green
            )])
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

        let repo = event.repository
        let repoName = repo.owner.login == "vapor" ? repo.name : repo.fullName

        let body = issue.body == nil ? "" : "\n\n>>> \(issue.body!)".prefix(264)

        let title = "\(repoName) #\(number): \(issue.title)"
        let descriptionHeader = "### Issue opened by **[\(creatorName)](\(creatorLink))**"

        try await client.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(embeds: [.init(
                title: String(title.prefix(256)),
                description: descriptionHeader + body,
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
