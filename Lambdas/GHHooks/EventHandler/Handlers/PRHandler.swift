import AsyncHTTPClient
import DiscordBM
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import GitHubAPI
import Markdown
import NIOCore
import NIOFoundationCompat
import SwiftSemver
import Shared

struct PRHandler {
    let context: HandlerContext
    let action: PullRequest.Action
    let pr: PullRequest
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
        case .assigned, .auto_merge_disabled, .auto_merge_enabled, .demilestoned, .labeled, .milestoned, .review_request_removed, .review_requested, .synchronize, .unassigned, .unlabeled, .submitted:
            break
        }
    }

    func onEdited() async throws {
        try await self.editPRReport()
    }

    func onOpened() async throws {
        try await self.makeReporter().reportCreation()
    }

    func onClosed() async throws {
        try await withThrowingAccumulatingVoidTaskGroup(tasks: [
            { try await self.makeRelease() },
            { try await self.editPRReport() },
        ])
    }

    func makeRelease() async throws {
        try await ReleaseMaker(
            context: self.context,
            pr: self.pr,
            number: self.event.number.requireValue()
        ).handle()
    }

    func editPRReport() async throws {
        try await self.makeReporter().reportEdition(
            requiresPreexistingReport: self.action == .labeled
        )
    }

    func makeReporter() async throws -> TicketReporter {
        try TicketReporter(
            context: self.context,
            embed: await self.createReportEmbed(),
            createdAt: self.pr.created_at,
            repoID: self.repo.id,
            number: self.event.number.requireValue(),
            authorID: self.pr.user.id
        )
    }

    func createReportEmbed() async throws -> Embed {
        let prLink = self.pr.html_url

        let body = self.pr.body.map { body -> String in
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
        let iconURL = member?.uiAvatarURL ?? self.pr.user.avatar_url

        let embed = Embed(
            title: title,
            description: description,
            url: prLink,
            timestamp: pr.created_at,
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
        if pr.merged_by != nil {
            self = .merged
        } else if pr.closed_at != nil {
            self = .closed
        } else if pr.draft == true {
            self = .draft
        } else {
            self = .opened
        }
    }
}
