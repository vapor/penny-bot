import DiscordBM
import GitHubAPI

struct IssueHandler: Sendable {
    let context: HandlerContext
    let issue: Issue
    var event: GHEvent {
        context.event
    }
    var repo: Repository {
        get throws {
            try event.repository.requireValue()
        }
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.issue = try context.event.issue.requireValue()
    }

    func handle() async throws {
        let action = try event.action
            .flatMap({ Issue.Action(rawValue: $0) })
            .requireValue()
        try await withThrowingAccumulatingVoidTaskGroup(tasks: [
            { try await handleIssue(action: action) },
            { try await handleProjectBoard(action: action) },
        ])
    }

    @Sendable
    func handleIssue(action: Issue.Action) async throws {
        switch action {
        case .opened:
            try await onOpened()
        case .closed, .deleted, .locked, .reopened, .unlocked, .edited:
            try await onEdited()
        case .transferred:
            try await onTransferred()
        case .assigned, .labeled, .demilestoned, .milestoned, .pinned, .unassigned, .unlabeled, .unpinned:
            break
        }
    }

    @Sendable
    func handleProjectBoard(action: Issue.Action) async throws {
        try await ProjectBoardHandler(
            context: context,
            action: action,
            issue: issue
        ).handle()
    }

    func onEdited() async throws {
        try await makeReporter().reportEdition()
    }

    func onOpened() async throws {
        try await makeReporter().reportCreation()
    }

    func onTransferred() async throws {
        let changes = try event.changes.requireValue()
        let newIssue = try changes.new_issue.requireValue()
        let newRepo = try changes.new_repository.requireValue()
        let repo = try repo
        let existingMessageID = try await context.messageLookupRepo.getMessageID(
            repoID: repo.id,
            number: issue.number
        )
        try await makeReporter(
            embedIssue: newIssue,
            embedRepo: changes.new_repository
        ).reportEdition()
        try await context.messageLookupRepo.markAsUnavailable(
            repoID: repo.id,
            number: issue.number
        )
        try await context.messageLookupRepo.saveMessageID(
            messageID: existingMessageID,
            repoID: newRepo.id,
            number: newIssue.number
        )
    }

    func makeReporter(
        embedIssue: Issue? = nil,
        embedRepo: Repository? = nil
    ) async throws -> TicketReporter {
        return TicketReporter(
            context: context,
            embed: try await createReportEmbed(
                issue: embedIssue,
                repo: embedRepo
            ),
            repoID: try repo.id,
            number: issue.number,
            ticketCreatedAt: issue.created_at
        )
    }

    func createReportEmbed(
        issue: Issue? = nil,
        repo: Repository? = nil
    ) async throws -> Embed {
        let issue = issue ?? self.issue
        let repo = try repo ?? self.repo

        let number = issue.number

        let issueLink = issue.html_url

        let body =
            issue.body.map { body -> String in
                body.formatMarkdown(
                    maxLength: 256,
                    trailingTextMinLength: 96
                )
            } ?? ""

        let description = try await context.renderClient.ticketReport(title: issue.title, body: body)

        let status = Status(issue: issue)
        let statusString = status.titleDescription.map { " - \($0)" } ?? ""
        let title = "[\(repo.uiName)] Issue #\(number)\(statusString)".unicodesPrefix(256)

        let member = try await context.requester.getDiscordMember(githubID: "\(issue.user.id)")
        let authorName = (member?.uiName).map { "@\($0)" } ?? issue.user.uiName
        let iconURL = member?.uiAvatarURL ?? issue.user.avatar_url

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
