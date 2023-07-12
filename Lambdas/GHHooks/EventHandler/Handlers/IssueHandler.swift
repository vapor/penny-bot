import DiscordBM

struct IssueHandler {
    let context: HandlerContext

    func handle() async throws {
        let action = context.event.action.map({ Issue.Action(rawValue: $0) })
        switch action {
        case .opened:
            try await onOpened()
        case .edited:
            try await onEdited()
        default: break
        }
    }

    func onEdited() async throws {
        let embed = try createReportEmbed()
        let reporter = Reporter(context: context)
        try await reporter.reportEdit(embed: embed)
    }

    func onOpened() async throws {
        let embed = try createReportEmbed()
        let reporter = Reporter(context: context)
        try await reporter.reportNew(embed: embed)
    }

    func createReportEmbed() throws -> Embed {
        let event = context.event

        let issue = try event.issue.requireValue()

        let number = try event.issue.requireValue().number

        let authorName = issue.user.login
        let authorAvatarLink = issue.user.avatar_url

        let issueLink = issue.html_url

        let repoName = event.repository.uiName

        let body = issue.body.map { "\n>>> \($0)".unicodesPrefix(264) } ?? ""

        let description = """
        ### \(issue.title)

        \(body)
        """

        return .init(
            title: "[\(repoName)] Issue #\(number)".unicodesPrefix(256),
            description: description,
            url: issueLink,
            color: .yellow,
            footer: .init(
                text: "By \(authorName)",
                icon_url: .exact(authorAvatarLink)
            )
        )
    }
}
