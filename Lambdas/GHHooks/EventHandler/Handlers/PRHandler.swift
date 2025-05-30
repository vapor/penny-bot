import DiscordBM
import GitHubAPI
import Logging
import Shared

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct PRHandler {
    let context: HandlerContext
    let action: PullRequest.Action
    let pr: PullRequest
    var event: GHEvent {
        self.context.event
    }
    var logger: Logger {
        context.logger
    }

    var repo: Repository {
        get throws {
            try self.event.repository.requireValue()
        }
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.action = try context.event.action
            .flatMap { PullRequest.Action(rawValue: $0) }
            .requireValue()
        self.pr = try context.event.pull_request.requireValue()
    }

    func handle() async throws {
        switch self.action {
        case .opened:
            try await self.onOpened()
        case .closed:
            try await self.onClosed()
        case .edited, .converted_to_draft, .dequeued, .enqueued, .locked, .ready_for_review, .reopened, .unlocked:
            try await self.onEdited()
        case .assigned, .auto_merge_disabled, .auto_merge_enabled, .demilestoned, .labeled, .milestoned,
            .review_request_removed, .review_requested, .synchronize, .unassigned, .unlabeled, .submitted:
            break
        }
    }

    func onEdited() async throws {
        if self.isIgnorableDoNotMergePR() { return }
        try await self.makeReporter().reportEdition(
            requiresPreexistingReport: self.action == .labeled
        )
    }

    func onOpened() async throws {
        if self.isIgnorableDoNotMergePR() { return }
        try await self.makeReporter().reportCreation()
    }

    func onClosed() async throws {
        try await withThrowingAccumulatingVoidTaskGroup(tasks: [
            { try await self.makeRelease() },
            { try await self.onEdited() },
        ])
    }

    func makeRelease() async throws {
        try await ReleaseMaker(
            context: self.context,
            pr: self.pr,
            number: self.event.number.requireValue()
        ).handle()
    }

    func makeReporter() async throws -> TicketReporter {
        try TicketReporter(
            context: self.context,
            embed: await self.createReportEmbed(),
            createdAt: self.pr.createdAt,
            repoID: self.repo.id,
            number: self.event.number.requireValue(),
            authorID: self.pr.user.id
        )
    }

    func createReportEmbed() async throws -> Embed {
        let prLink = self.pr.htmlUrl

        let body =
            self.pr.body.map { body -> String in
                body.formatMarkdown(
                    maxVisualLength: 256,
                    hardLimit: 2_048,
                    trailingTextMinLength: 96
                )
            } ?? ""

        let description = try await context.renderClient.ticketReport(title: self.pr.title, body: body)

        let status = Status(pr: pr)
        let statusString = status.titleDescription.map { " - \($0)" } ?? ""
        let number = try event.number.requireValue()
        let title = try "[\(repo.uiName)] PR #\(number)\(statusString)".unicodesPrefix(256)

        let member = try await context.requester.getDiscordMember(githubID: "\(self.pr.user.id)")
        let authorName = (member?.uiName).map { "@\($0)" } ?? self.pr.user.uiName
        let iconURL = member?.uiAvatarURL ?? self.pr.user.avatarUrl

        let embed = Embed(
            title: title,
            description: description,
            url: prLink,
            timestamp: pr.createdAt,
            color: status.color,
            footer: .init(
                text: "By \(authorName)",
                icon_url: .exact(iconURL)
            )
        )

        return embed
    }

    func isIgnorableDoNotMergePR() -> Bool {
        let isIgnorable = self.pr.isIgnorableDoNotMergePR
        if isIgnorable {
            logger.info(
                "PR is ignorable",
                metadata: [
                    "pr": "\(self.pr)"
                ]
            )
        }
        return isIgnorable
    }
}

private enum Status: String {
    case merged = "Merged"
    case closed = "Closed"
    case draft = "Draft"
    case opened = "Opened"

    var color: DiscordColor {
        switch self {
        case .merged:
            return .purple
        case .closed:
            return .red
        case .draft:
            return .gray
        case .opened:
            return .green
        }
    }

    var titleDescription: String? {
        switch self {
        case .opened:
            return nil
        case .merged, .closed, .draft:
            return self.rawValue
        }
    }

    init(pr: PullRequest) {
        if pr.mergedAt != nil {
            self = .merged
        } else if pr.closedAt != nil {
            self = .closed
        } else if pr.draft == true {
            self = .draft
        } else {
            self = .opened
        }
    }
}
