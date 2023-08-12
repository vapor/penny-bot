import DiscordBM
import AsyncHTTPClient
import NIOCore
import NIOFoundationCompat
import GitHubAPI
import SwiftSemver
import Markdown
import Foundation

struct PRHandler {

    enum Configuration {
        static let userIDDenyList: Set<Int> = [/*dependabot[bot]:*/ 49699333]
    }

    let context: HandlerContext
    let pr: PullRequest
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
        self.pr = try context.event.pull_request.requireValue()
    }

    func handle() async throws {
        let action = try event.action
            .flatMap({ PullRequest.Action(rawValue: $0) })
            .requireValue()
        guard !Configuration.userIDDenyList.contains(pr.user.id) else {
            return
        }
        switch action {
        case .opened:
            try await onOpened()
        case .closed:
            try await onClosed()
        case .edited, .converted_to_draft, .dequeued, .enqueued, .locked, .ready_for_review, .reopened, .unlocked:
            try await onEdited()
        case .assigned, .auto_merge_disabled, .auto_merge_enabled, .demilestoned, .labeled, .milestoned, .review_request_removed, .review_requested, .synchronize, .unassigned, .unlabeled, .submitted:
            break
        }
    }

    func onEdited() async throws {
        try await editPRReport()
    }

    func onOpened() async throws {
        try await makeReporter().reportCreation()
    }

    func onClosed() async throws {
        try await ReleaseMaker(
            context: context,
            pr: pr,
            number: event.number.requireValue()
        ).handle()
        try await editPRReport()
    }

    func editPRReport() async throws {
        try await makeReporter().reportEdition()
    }

    func makeReporter() async throws -> TicketReporter {
        TicketReporter(
            context: context,
            embed: try await createReportEmbed(),
            repoID: try repo.id,
            number: try event.number.requireValue(),
            ticketCreatedAt: pr.created_at
        )
    }

    func createReportEmbed() async throws -> Embed {
        let prLink = pr.html_url

        let body = pr.body.map { body -> String in
            body.formatMarkdown(
                maxLength: 256,
                trailingTextMinLength: 96
            )
        } ?? ""

        let description = try await context.renderClient.ticketReport(title: pr.title, body: body)

        let status = Status(pr: pr)
        let statusString = status.titleDescription.map { " - \($0)" } ?? ""
        let number = try event.number.requireValue()
        let title = try "[\(repo.uiName)] PR #\(number)\(statusString)".unicodesPrefix(256)

        let member = try await context.requester.getDiscordMember(githubID: "\(pr.user.id)")
        let authorName = (member?.uiName).map { "@\($0)" } ?? pr.user.uiName
        let iconURL = member?.uiAvatarURL ?? pr.user.avatar_url

        let embed = Embed(
            title: title,
            description: description,
            url: prLink,
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
