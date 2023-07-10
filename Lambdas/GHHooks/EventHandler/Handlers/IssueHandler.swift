import DiscordBM

struct IssueHandler {
    let context: HandlerContext

    func handle() async throws {
        let action = context.event.action.map({ Issue.Action(rawValue: $0) })
        switch action {
        case .opened:
            try await onOpened()
        default: break
        }
    }

    func onOpened() async throws {
        let event = context.event

        let issue = try event.issue.requireValue()

        let number = try event.issue.requireValue().number

        let user = issue.user
        let creatorName = user.login
        let creatorLink = user.html_url

        let issueLink = issue.html_url

        let repo = event.repository
        let repoName = repo.organization?.name == "vapor" ? repo.name : repo.full_name

        let body = issue.body.map { "\n\n>>> \($0)".unicodesPrefix(264) } ?? ""

        let description = """
        ### \(issue.title)

        **By [\(creatorName)](\(creatorLink))**
        \(body)
        """

        try await context.discordClient.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(embeds: [.init(
                title: "[\(repoName)] Issue #\(number)".unicodesPrefix(256),
                description: description,
                url: issueLink,
                color: .yellow
            )])
        ).guardSuccess()
    }
}
