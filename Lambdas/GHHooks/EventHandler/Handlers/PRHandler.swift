import DiscordBM
import AsyncHTTPClient
import NIOCore
import NIOFoundationCompat
import GitHubAPI
import SwiftSemver
import Markdown
import Foundation

struct PRHandler {

    enum PRErrors: Error, CustomStringConvertible, LocalizedError {
        case tagDoesNotFollowSemVer(release: Release, tag: String)
        case cantBumpSemVer(version: SemanticVersion, bump: SemVerBump)
        case cantFindAnyRelease(latest: Release?, releases: [Release])

        var description: String {
            switch self {
            case let .tagDoesNotFollowSemVer(release, tag):
                return "tagDoesNotFollowSemVer(release: \(release), tag: \(tag))"
            case let .cantBumpSemVer(version, bump):
                return "cantBumpSemVer(version: \(version), bump: \(bump))"
            case let .cantFindAnyRelease(latest, releases):
                return "cantFindAnyRelease(latest: \(String(describing: latest)), releases: \(releases))"
            }
        }

        var errorDescription: String? {
            description
        }
    }

    let context: HandlerContext
    let pr: PullRequest
    let number: Int
    var event: GHEvent {
        context.event
    }
    var repo: Repository {
        event.repository
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.pr = try context.event.pull_request.requireValue()
        self.number = try context.event.number.requireValue()
    }

    func handle() async throws {
        let action = try event.action
            .flatMap({ PullRequest.Action(rawValue: $0) })
            .requireValue()
        switch action {
        case .opened:
            try await onOpened()
        case .closed:
            try await onClosed()
        case .edited, .converted_to_draft, .dequeued, .enqueued, .locked, .ready_for_review, .reopened, .unlocked:
            try await onEdited()
        case .assigned, .auto_merge_disabled, .auto_merge_enabled, .demilestoned, .labeled, .milestoned, .review_request_removed, .review_requested, .synchronize, .unassigned, .unlabeled:
            break
        }
    }

    func onEdited() async throws {
        try await editPRReport()
    }

    func onOpened() async throws {
        let embed = createReportEmbed()
        let reporter = Reporter(context: context)
        try await reporter.reportNew(embed: embed)
    }

    func onClosed() async throws {
        try await makeReleaseForMergedPR()
        try await editPRReport()
    }

    func makeReleaseForMergedPR() async throws {
        guard pr.base.ref == "main",
              let mergedBy = pr.merged_by,
              let bump = pr.knownLabels.first?.toBump()
        else { return }

        let previousRelease = try await getLastRelease()

        let tag = previousRelease.tag_name
        guard let (tagPrefix, previousVersion) = SemanticVersion.fromGitHubTag(tag) else {
            throw PRErrors.tagDoesNotFollowSemVer(release: previousRelease, tag: tag)
        }

        guard let version = previousVersion.next(bump) else {
            throw PRErrors.cantBumpSemVer(version: previousVersion, bump: bump)
        }
        let versionDescription = tagPrefix + version.description

        let release = try await makeNewRelease(
            version: versionDescription,
            mergedBy: mergedBy,
            isPrerelease: !version.prereleaseIdentifiers.isEmpty
        )

        try await sendComment(release: release)

        try await context.discordClient.createMessage(
            channelId: Constants.Channels.release.id,
            payload: .init(
                content: """
                [\(repo.uiName)] \(version.description): \(pr.title)
                \(release.html_url)
                """
            )
        ).guardSuccess()
    }

    func editPRReport() async throws {
        let embed = createReportEmbed()
        let reporter = Reporter(context: context)
        try await reporter.reportEdit(embed: embed)
    }

    func createReportEmbed() -> Embed {
        let authorName = pr.user.login
        let authorAvatarLink = pr.user.avatar_url

        let prLink = pr.html_url

        let body = pr.body.map { body -> String in
            let formatted = body.formatForDiscord(
                maxLength: 256,
                trailingParagraphMinLength: 128
            )
            return formatted.isEmpty ? "" : ">>> \(formatted)"
        } ?? ""

        let description = """
        ### \(pr.title)

        \(body)
        """

        let status = Status(pr: pr)
        let statusString = status.titleDescription.map { " - \($0)" } ?? ""
        let maxCount = 256 - statusString.unicodeScalars.count
        let title = "[\(repo.uiName)] PR #\(number)".unicodesPrefix(maxCount) + statusString

        let embed = Embed(
            title: title,
            description: description,
            url: prLink,
            color: status.color,
            footer: .init(
                text: "By \(authorName)",
                icon_url: .exact(authorAvatarLink)
            )
        )

        return embed
    }
}

extension PRHandler {
    func getLastRelease() async throws -> Release {
        let latest = try await self.getLatestRelease()

        let response = try await context.githubClient.repos_list_releases(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            )
        ))

        guard case let .ok(ok) = response,
              case let .json(releases) = ok.body
        else {
            throw Errors.httpRequestFailed(response: response)
        }

        let filteredReleases: [Release] = releases.compactMap {
            release -> (Release, SemanticVersion)? in
            if let (_, version) = SemanticVersion.fromGitHubTag(release.tag_name) {
                return (release, version)
            }
            return nil
        }.filter { release, version -> Bool in
            if let majorVersion = Int(pr.base.ref) {
                /// If the branch name is an integer, only include releases
                /// for that major version.
                return version.major == majorVersion
            }
            return true
        }.sorted {
            $0.1 > $1.1
        }.sorted { (lhs, rhs) in
            if let latest {
                return latest.id == lhs.0.id
            }
            return true
        }.map(\.0)

        guard let release = filteredReleases.first else {
            throw PRErrors.cantFindAnyRelease(latest: latest, releases: releases)
        }

        return release
    }

    private func getLatestRelease() async throws -> Release? {
        let response = try await context.githubClient.repos_get_latest_release(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            )
        ))

        switch response {
        case let .ok(ok):
            switch ok.body {
            case let .json(json):
                return json
            }
        default: break
        }

        context.logger.warning("Could not find a 'latest' release", metadata: [
            "owner": .string(repo.owner.login),
            "name": .string(repo.name),
            "response": "\(response)",
        ])

        return nil
    }

    func makeNewRelease(
        version: String,
        mergedBy: NullableUser,
        isPrerelease: Bool
    ) async throws -> Release {
        let body = try await makeReleaseBody(mergedBy: mergedBy)
        let response = try await context.githubClient.repos_create_release(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            ),
            body: .json(.init(
                tag_name: version,
                target_commitish: pr.base.ref,
                name: "\(version) - \(pr.title)",
                body: body,
                draft: false,
                prerelease: isPrerelease,
                make_latest: isPrerelease ? ._false : ._true
            ))
        ))

        switch response {
        case let .created(created):
            switch created.body {
            case let .json(release):
                return release
            }
        default: break
        }

        throw Errors.httpRequestFailed(response: response)
    }

    func sendComment(release: Release) async throws {
        /// `"Issues" create comment`, but works for PRs too. Didn't find an endpoint for PRs.
        let response = try await context.githubClient.issues_create_comment(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                issue_number: number
            ),
            body: .json(.init(
                body: """
                These changes are now available in [\(release.tag_name)](\(release.html_url))
                """
            ))
        ))

        switch response {
        case .created: return
        default:
            throw Errors.httpRequestFailed(response: response)
        }
    }

    /**
     - A user who appears in a given repo's code owners file should NOT be credited as either an author or reviewer for a release in that repo (but can still be credited for releasing it).
     - The user who authored the PR should be credited unless they are a code owner. Such a credit should be prominent and - as the GitHub changelog generator does - include a notation if it's that user's first merged PR.
     - Any users who reviewed the PR (even if they requested changes or did a comments-only review without approving) should also be credited unless they are code owners. Such a credit should be less prominent than the author credit, something like a "thanks to ... for helping to review this release"
     - The release author (user who merged the PR) should always be credited in a release, even if they're a code owner. This credit should be the least prominent, maybe even just a footnote (since it will pretty much always be a owner/maintainer).
     */
    func makeReleaseBody(
        mergedBy: Components.Schemas.nullable_simple_user
    ) async throws -> String {
        let codeOwners = try await getCodeOwners()

        let acknowledgment: String

        let author = pr.user.login
        let merger = mergedBy.login

        /// If author is a code owner, skip crediting them as the author.
        if codeOwners.contains(author) {
            acknowledgment = "This patch was released by @\(author)."
        } else {
            if author == merger {
                acknowledgment = "This patch was authored and released by @\(author)."
            } else {
                acknowledgment = "This patch was authored by @\(author) and released by @\(merger)."
            }
        }

        return """
        ###### _\(acknowledgment)_

        "\(pr.body ?? "Pull Request:") \(pr.html_url)"
        """
    }

    /// Returns code owners if the repo contains the file or returns `nil`.
    /// In form of `["gwynne", "0xTim"]`.
    func getCodeOwners() async throws -> Set<String> {
        let fullName = repo.full_name.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? repo.full_name
        let url = "https://raw.githubusercontent.com/\(fullName)/main/.github/CODEOWNERS"
        let request = HTTPClientRequest(url: url)
        let response = try await context.httpClient.execute(request, timeout: .seconds(3))
        guard response.status == .ok else {
            context.logger.debug("Can't find code owners of repo")
            return []
        }
        let body = try await response.body.collect(upTo: 1 << 16)
        let text = String(buffer: body)
        return parseCodeOwners(text: text)
    }

    func parseCodeOwners(text: String) -> Set<String> {
        let codeOwners: [String] = text
        /// split into lines
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
        /// trim leading whitespace per line
            .map { $0.trimmingPrefix(while: \.isWhitespace) }
        /// remove whole-line comments
            .filter { !$0.starts(with: "#") }
        /// remove partial-line comments
            .compactMap {
                $0.split(
                    separator: "#",
                    maxSplits: 1,
                    omittingEmptySubsequences: true
                ).first
            }
        /// split lines on whitespace, dropping first word, and combine to single list
            .flatMap {
                $0.split(
                    omittingEmptySubsequences: true,
                    whereSeparator: \.isWhitespace
                ).dropFirst()
            }.map(String.init)

        return Set(codeOwners)
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
