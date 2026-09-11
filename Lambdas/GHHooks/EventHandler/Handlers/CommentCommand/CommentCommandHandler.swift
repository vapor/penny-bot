import DiscordBM
import GitHubAPI
import Logging
import OpenAPIRuntime
import Shared

struct CommentCommandHandler {
    enum Configuration {
        static let organizationIDAllowList: Set<Int64> = [Constants.GitHub.vaporOrgID]
        static let reportMarker = "<!-- penny-command-report -->"
    }

    let context: HandlerContext
    let action: IssueComment.Action
    let repo: Repository
    let comment: IssueComment
    let issue: Issue
    var logger: Logger

    var event: GHEvent {
        self.context.event
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.action = try context.event.action
            .flatMap { IssueComment.Action(rawValue: $0) }
            .requireValue()
        self.repo = try context.event.repository.requireValue()
        self.comment = try context.event.comment.requireValue()
        self.issue = try context.event.issue.requireValue()
        self.logger = context.logger
        self.logger[metadataKey: "repo"] = .string(self.repo.fullName)
        self.logger[metadataKey: "number"] = .stringConvertible(self.issue.number)
        self.logger[metadataKey: "sender"] = .string(self.event.sender?.login ?? "<unknown>")
    }

    func handle() async throws {
        switch self.action {
        case .created:
            try await self.onCreated()
        case .deleted, .edited, .pinned, .unpinned:
            break
        }
    }

    func onCreated() async throws {
        guard Configuration.organizationIDAllowList.contains(self.repo.owner.id) else { return }

        let sender = try self.event.sender.requireValue()
        guard !sender.isBot, sender.id != Constants.GitHub.userID else { return }

        switch CommentCommand.parse(commentBody: self.comment.body ?? "") {
        case .noMention:
            return
        case let .unknownCommand(verb):
            try await self.fail(with: .unknownCommand(verb: verb), sender: sender)
        case let .command(command):
            try await self.react(with: .eyes)
            do {
                let sha = try await self.run(command, sender: sender)
                try await self.react(with: .rocket)
                self.logger.info(
                    "Ran a comment command",
                    metadata: [
                        "command": .string(command.rawValue),
                        "againstSHA": .string(sha),
                    ]
                )
            } catch let error as CommentCommandError {
                try await self.fail(with: error, sender: sender)
            }
        }
    }

    func fail(with error: CommentCommandError, sender: User) async throws {
        self.logger.info(
            "Comment command failed",
            metadata: ["error": .string(error.description)]
        )
        try await self.react(with: .confused)
        try await self.report(error.commentBody)
    }

    /// Returns the sha the command was run against.
    func run(_ command: CommentCommand, sender: User) async throws -> String {
        guard self.issue.pullRequest != nil else {
            throw CommentCommandError.notAPullRequest(command: command)
        }
        try await self.requireWriteAccess(of: sender)
        switch command {
        case .benchmark:
            return try await BenchmarkCommand(
                context: self.context,
                number: self.issue.number
            ).handle()
        }
    }

    func requireWriteAccess(of sender: User) async throws {
        let response = try await self.context.githubClient.reposGetCollaboratorPermissionLevel(
            path: .init(
                owner: self.repo.owner.login,
                repo: self.repo.name,
                username: sender.login
            )
        )
        switch response {
        case let .ok(ok):
            let permission = try ok.body.json.permission
            guard ["admin", "write"].contains(permission) else {
                throw CommentCommandError.insufficientAccess(
                    login: sender.login,
                    repo: self.repo.fullName,
                    permission: permission
                )
            }
        case .notFound:
            throw CommentCommandError.insufficientAccess(
                login: sender.login,
                repo: self.repo.fullName,
                permission: "none"
            )
        default:
            throw Errors.httpRequestFailed(response: response)
        }
    }

    func react(with content: ReactionContent) async throws {
        let response = try await self.context.githubClient.reactionsCreateForIssueComment(
            path: .init(
                owner: self.repo.owner.login,
                repo: self.repo.name,
                commentId: self.comment.id
            ),
            body: .json(.init(content: content))
        )
        switch response {
        case .ok, .created:
            break
        default:
            self.logger.warning(
                "Could not react to a comment",
                metadata: [
                    "response": "\(response)"
                ]
            )
        }
    }

    func report(_ body: String) async throws {
        let body = "\(Configuration.reportMarker)\n\(body)"

        if let existing = try await self.findReportComment() {
            _ = try await self.context.githubClient.issuesUpdateComment(
                path: .init(
                    owner: self.repo.owner.login,
                    repo: self.repo.name,
                    commentId: existing.id
                ),
                body: .json(.init(body: body))
            ).ok
        } else {
            _ = try await self.context.githubClient.issuesCreateComment(
                path: .init(
                    owner: self.repo.owner.login,
                    repo: self.repo.name,
                    issueNumber: self.issue.number
                ),
                body: .json(.init(body: body))
            ).created
        }
    }

    static func isReportComment(_ comment: IssueComment) -> Bool {
        guard let userID = comment.user?.id, userID == Constants.GitHub.userID else {
            return false
        }
        return (comment.body ?? "").contains(Configuration.reportMarker)
    }

    func findReportComment() async throws -> IssueComment? {
        var page = 1
        var found: IssueComment?
        while true {
            let ok = try await self.context.githubClient.issuesListComments(
                path: .init(
                    owner: self.repo.owner.login,
                    repo: self.repo.name,
                    issueNumber: self.issue.number
                ),
                query: .init(
                    perPage: 100,
                    page: page
                )
            ).ok
            let comments = try ok.body.json
            if let match = comments.last(where: Self.isReportComment) {
                found = match
            }
            /// See `ReleaseMaker.getExistingContributorIDs()` for the shape of a `link` header.
            let hasNext =
                switch ok.headers.link {
                case let .some(string):
                    string.contains(#"rel="next""#)
                case .none:
                    false
                }
            if !hasNext {
                return found
            }
            page += 1
        }
    }
}
