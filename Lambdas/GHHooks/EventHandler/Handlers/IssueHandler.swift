import DiscordBM
import Markdown

struct IssueHandler {
    let context: HandlerContext

    func handle() async throws {
        let action = context.event.action.map({ Issue.Action(rawValue: $0) })
        switch action {
        case .opened:
            try await onOpened()
        case .edited:
            try await onEdited()
        case .closed:
            try await onClosed()
        default: break
        }
    }

    func onEdited() async throws {
        try await editIssueReport()
    }

    func onOpened() async throws {
        let (embed, _) = try createReportEmbed()
        let reporter = Reporter(context: context)
        try await reporter.reportNew(embed: embed)
    }

    func onClosed() async throws {
        try await editIssueReport()
    }

    func editIssueReport() async throws {
        let (embed, properties) = try createReportEmbed()
        let reporter = Reporter(context: context)
        try await reporter.reportEdit(embed: embed, searchableTitleProperties: properties)
    }

    func createReportEmbed() throws -> (embed: Embed, searchableTitleProperties: [String]) {
        let event = context.event

        let issue = try event.issue.requireValue()

        let number = try event.issue.requireValue().number

        let authorName = issue.user.login
        let authorAvatarLink = issue.user.avatar_url

        let issueLink = issue.html_url

        let repoName = event.repository.uiName

        let body = issue.body.map { body in
            let formatted = Document(parsing: body)
                .filterOutChildren(ofType: HTMLBlock.self)
                .format()
            return ">>> \(formatted)".unicodesPrefix(260)
        } ?? ""

        let description = """
        ### \(issue.title)

        \(body)
        """

        let status = Status(issue: issue)
        let statusString = status.titleDescription.map { " - \($0)" } ?? ""
        let maxCount = 256 - statusString.unicodeScalars.count
        let title = "[\(repoName)] Issue #\(number)".unicodesPrefix(maxCount) + statusString
        /// A few string that the title contains, to search and uniquely identify the message with.
        let searchableTitleProperties = [repoName, "Issue", "#\(number)"]

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

        return (embed, searchableTitleProperties)
    }
}

private enum Status: String {
    case closed = "Closed"
    case opened = "Opened"

    var color: DiscordColor {
        switch self {
        case .closed:
            return .init(red: 153, green: 153, blue: 153)! /// Gray
        case .opened:
            return .yellow
        }
    }

    var titleDescription: String? {
        switch self {
        case .closed:
            return self.rawValue
        case .opened:
            return nil
        }
    }

    init(issue: Issue) {
        if issue.closed_at != nil {
            self = .closed
        } else {
            self = .opened
        }
    }
}
