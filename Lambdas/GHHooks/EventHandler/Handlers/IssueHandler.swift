import DiscordBM
import GitHubAPI
import Markdown

struct IssueHandler {
    let context: HandlerContext
    var event: GHEvent {
        context.event
    }
    let repoID: Int
    let number: Int

    init(context: HandlerContext) throws {
        self.context = context
        self.repoID = try context.event.repository.requireValue().id
        self.number = try context.event.issue.requireValue().number
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
        try await editIssueReport()
    }

    func onOpened() async throws {
        let embed = try createReportEmbed()
        let reporter = Reporter(context: context)
        try await reporter.reportNew(embed: embed, repoID: repoID, number: number)
    }

    func editIssueReport() async throws {
        let embed = try createReportEmbed()
        let reporter = Reporter(context: context)
        try await reporter.reportEdit(embed: embed, repoID: repoID, number: number)
    }

    func createReportEmbed() throws -> Embed {
        let issue = try event.issue.requireValue()

        let number = try event.issue.requireValue().number

        let authorName = issue.user.login
        let authorAvatarLink = issue.user.avatar_url

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

        let embed = Embed(
            title: title,
            description: description,
            url: issueLink,
            color: status.color,
            footer: .init(
                text: "By \(authorName)",
                icon_url: .exact(authorAvatarLink)
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
