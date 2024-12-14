import DiscordBM
import GitHubAPI

struct IssueHandler: Sendable {
    let context: HandlerContext
    let action: Issue.Action
    let issue: Issue
    var event: GHEvent {
        self.context.event
    }

    var repo: Repository {
        get throws {
            try self.event.repository.requireValue()
        }
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.action = try context.event
            .action
            .flatMap { Issue.Action(rawValue: $0) }
            .requireValue()
        self.issue = try context.event.issue.requireValue()
    }

    func handle() async throws {
        try await withThrowingAccumulatingVoidTaskGroup(tasks: [
            { try await self.handleIssue() },
            { try await self.handleProjectBoard() },
        ])
    }

    @Sendable
    func handleIssue() async throws {
        switch self.action {
        case .opened:
            try await self.onOpened()
        case .closed, .deleted, .locked, .reopened, .unlocked, .edited, .labeled, .unlabeled:
            try await self.onEdited()
        case .transferred:
            try await self.onTransferred()
        case .assigned, .demilestoned, .milestoned, .pinned, .unassigned, .unpinned:
            break
        }
    }

    @Sendable
    func handleProjectBoard() async throws {
        try await ProjectBoardHandler(
            context: self.context,
            action: self.action,
            issue: self.issue
        ).handle()
    }

    func onEdited() async throws {
        try await self.makeReporter().reportEdition(
            requiresPreexistingReport: self.action == .labeled
        )
    }

    func onOpened() async throws {
        try await self.makeReporter().reportCreation()
    }

    func onTransferred() async throws {
        let changes = try event.changes.requireValue()
        let newIssue = try changes.new_issue.requireValue()
        let newRepo = try changes.new_repository.requireValue()
        let repo = try repo
        let existingMessageID = try await context.messageLookupRepo.getMessageID(
            repoID: repo.id,
            number: self.issue.number
        )
        try await self.makeReporter(
            embedIssue: newIssue,
            embedRepo: changes.new_repository
        ).reportEdition(
            requiresPreexistingReport: self.action == .labeled
        )
        try await self.context.messageLookupRepo.markAsUnavailable(
            repoID: repo.id,
            number: self.issue.number
        )
        try await self.context.messageLookupRepo.saveMessageID(
            messageID: existingMessageID,
            repoID: newRepo.id,
            number: newIssue.number
        )
    }

    func makeReporter(
        embedIssue: Issue? = nil,
        embedRepo: Repository? = nil
    ) async throws -> TicketReporter {
        try TicketReporter(
            context: self.context,
            embed: await self.createReportEmbed(
                issue: embedIssue,
                repo: embedRepo
            ),
            createdAt: self.issue.created_at,
            repoID: self.repo.id,
            number: self.issue.number,
            authorID: self.issue.user.requireValue().id
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
                    maxVisualLength: 256,
                    hardLimit: 2_048,
                    trailingTextMinLength: 96
                )
            } ?? ""

        let description = try await context.renderClient
            .ticketReport(title: issue.title, body: body)
            .unicodesPrefix(512)

        let status = Status(issue: issue)
        let statusString = status.titleDescription.map { " - \($0)" } ?? ""
        let title = "[\(repo.uiName)] Issue #\(number)\(statusString)".unicodesPrefix(256)
        let user = try issue.user.requireValue()

        let member = try await context.requester.getDiscordMember(githubID: "\(user.id)")
        let authorName = (member?.uiName).map { "@\($0)" } ?? user.uiName

        var iconURL = member?.uiAvatarURL ?? user.avatar_url
        var footer = "By \(authorName)"
        if let verb = status.closedByVerb,
            let closedBy = try await self.maybeGetClosedByUser()
        {
            if closedBy.id == issue.user?.id {
                /// The same person opened and closed the issue.
                footer = "Filed & \(verb) by \(authorName)"
            } else {
                let resolverMember = try await self.context.requester
                    .getDiscordMember(githubID: "\(closedBy.id)")
                if let url = resolverMember?.uiAvatarURL ?? issue.closed_by?.avatar_url {
                    iconURL = url
                }
                let uiName = (resolverMember?.uiName).map { "@\($0)" } ?? closedBy.uiName
                footer = "By \(authorName) | \(verb) by \(uiName)"
            }
        }

        let embed = Embed(
            title: title,
            description: description,
            url: issueLink,
            timestamp: issue.created_at,
            color: status.color,
            footer: .init(
                text: footer.unicodesPrefix(100),
                icon_url: .exact(iconURL)
            )
        )

        return embed
    }

    /// Returns the `closed-by` user if the issue is closed at all.
    func maybeGetClosedByUser() async throws -> (id: Int, uiName: String)? {
        if issue.closed_at == nil {
            return nil
        }
        if action == .closed {
            return (event.sender.id, event.sender.uiName)
        } else {
            return try await context.githubClient.issues_get(
                path: .init(
                    owner: repo.owner.login,
                    repo: repo.name,
                    issue_number: issue.number
                )
            ).ok.body.json.closed_by.map {
                ($0.id, $0.uiName)
            }
        }
    }
}

private enum Status: String {
    case done = "Done"
    case notPlanned = "Not Planned"
    case duplicate = "Duplicate"
    case open = "Open"

    var color: DiscordColor {
        switch self {
        case .done:
            return .teal
        case .notPlanned:
            return .gray(level: .level2, scheme: .dark)
        case .duplicate:
            return .mint
        case .open:
            return .yellow
        }
    }

    var titleDescription: String? {
        switch self {
        case .done, .notPlanned, .duplicate:
            return self.rawValue
        case .open:
            return nil
        }
    }

    var closedByVerb: String? {
        switch self {
        case .done:
            return "Resolved"
        case .notPlanned, .duplicate:
            return "Closed"
        case .open:
            return nil
        }
    }

    init(issue: Issue) {
        if issue.knownLabels.contains(.duplicate) {
            self = .duplicate
        } else if issue.state_reason == .not_planned {
            self = .notPlanned
        } else if issue.closed_at != nil {
            self = .done
        } else {
            self = .open
        }
    }
}
