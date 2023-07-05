import DiscordBM

struct PRHandler {
    let context: HandlerContext

    func handle() async throws {
        let action = context.event.action.map({ PullRequest.Action(rawValue: $0) })
        switch action {
        case .opened:
            try await onOpened()
        default: break
        }
    }

    func onOpened() async throws {
        let event = context.event

        let pr = try event.pull_request.requireValue()

        let number = try event.number.requireValue()

        let creatorName = pr.user.login
        let creatorLink = pr.user.html_url

        let prLink = pr.html_url

        let repo = event.repository
        let repoName = repo.organization?.name == "vapor" ? repo.name : repo.full_name

        let body = pr.body == nil ? "" : "\n\n>>> \(pr.body!)".unicodesPrefix(264)

        let description = """
        ## \(pr.title)

        ### By **[\(creatorName)](\(creatorLink))**
        \(body)
        """

        try await context.discordClient.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(embeds: [.init(
                title: "[\(repoName)] PR #\(number)".unicodesPrefix(256),
                description: description,
                url: prLink,
                color: .green
            )])
        ).guardSuccess()
    }
}
