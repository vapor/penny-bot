import DiscordBM
import GitHubAPI
import Markdown

struct IssueHandler {
    let context: HandlerContext
    let issue: Issue
    var event: GHEvent {
        context.event
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.issue = try context.event.issue.requireValue()
    }

    func handle() async throws {
        let action = try event.action
            .flatMap({ Issue.Action(rawValue: $0) })
            .requireValue()
        switch action {
        case .opened:
            try await onOpened()
        case .closed, .deleted, .locked, .reopened, .unlocked, .edited:
            try await onEdited()
        case .assigned, .labeled, .demilestoned, .milestoned, .pinned, .transferred, .unassigned, .unlabeled, .unpinned:
            break
        }
    }

    func onEdited() async throws {
        try await makeReporter().reportEdition()
    }

    func onOpened() async throws {
        try await makeReporter().reportCreation()
    }

    func makeReporter() async throws -> Reporter {
        Reporter(
            context: context,
            embed: try await createReportEmbed(),
            repoID: try context.event.repository.requireValue().id,
            number: issue.number,
            ticketCreatedAt: issue.created_at
        )
    }

    func createReportEmbed() async throws -> Embed {
        let number = issue.number

        let issueLink = issue.html_url

        let repoName = try event.repository.requireValue().uiName

        let body = issue.body.map { body -> String in
            let formatted = body.formatMarkdown(
                maxLength: 256,
                trailingParagraphMinLength: 128
            )
            return formatted.isEmpty ? "" : ">>> \(formatted)"
        } ?? ""

        let description = """
        ### \(issue.title)

        \(body)
        """

        let status = Status(issue: issue)
        let statusString = status.titleDescription.map { " - \($0)" } ?? ""
        let maxCount = 256 - statusString.unicodeScalars.count
        let title = "[\(repoName)] Issue #\(number)".unicodesPrefix(maxCount) + statusString

        let member = try await context.getDiscordMember(githubID: "\(issue.user.id)")
        let authorName = (member?.uiName).map { "@\($0)" } ?? issue.user.uiName
        let iconURL = member?.uiAvatarCDNEndpoint?.url ?? issue.user.avatar_url

        let embed = Embed(
            title: title,
            description: description,
            url: issueLink,
            color: status.color,
            footer: .init(
                text: "By \(authorName)",
                icon_url: .exact(iconURL)
            )
        )

        return embed
    }
}

private enum Status: String {
    case done = "Done"
    case notPlanned = "Not Planned"
    case opened = "Opened"

    var color: DiscordColor {
        switch self {
        case .done:
            return .teal
        case .notPlanned:
            return .gray(level: .level2, scheme: .dark)
        case .opened:
            return .yellow
        }
    }

    var titleDescription: String? {
        switch self {
        case .done, .notPlanned:
            return self.rawValue
        case .opened:
            return nil
        }
    }

    init(issue: Issue) {
        if issue.state_reason == .not_planned {
            self = .notPlanned
        } else if issue.closed_at != nil {
            self = .done
        } else {
            self = .opened
        }
    }
}
