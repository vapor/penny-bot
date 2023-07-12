import DiscordBM
import AsyncHTTPClient
import SwiftSemver
import Markdown
import NIOCore
import NIOFoundationCompat
import Foundation

struct PRHandler {

    enum Errors: Error, CustomStringConvertible {
        case httpRequestFailed(response: Any, file: String = #filePath, line: UInt = #line)
        case tagDoesNotFollowSemVer(release: Components.Schemas.release, tag: String)
        case cantBumpSemVer(version: SemanticVersion, bump: SemVerBump)
        case cantFindAnyRelease(
            latest: Components.Schemas.release?,
            releases: [Components.Schemas.release]
        )

        var description: String {
            switch self {
            case let .httpRequestFailed(response, file, line):
                return "httpRequestFailed(response: \(response), file: \(file), line: \(line))"
            case let .tagDoesNotFollowSemVer(release, tag):
                return "tagDoesNotFollowSemVer(release: \(release), tag: \(tag))"
            case let .cantBumpSemVer(version, bump):
                return "cantBumpSemVer(version: \(version), bump: \(bump))"
            case let .cantFindAnyRelease(latest, releases):
                return "cantFindAnyRelease(latest: \(String(describing: latest)), releases: \(releases))"
            }
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
        let action = context.event.action.map({ PullRequest.Action(rawValue: $0) })
        switch action {
        case .opened:
            try await onOpened()
        case .closed:
            try await onClosed()
        case .edited:
            try await onEdited()
        default: break
        }
    }

    func onEdited() async throws {
        let embed = createReportEmbed()
        let reporter = Reporter(context: context)
        try await reporter.reportEdit(embed: embed)
    }

    func onOpened() async throws {
        let embed = createReportEmbed()
        let reporter = Reporter(context: context)
        try await reporter.reportNew(embed: embed)
    }

    func createReportEmbed() -> Embed {
        let authorName = pr.user.login
        let authorAvatarLink = pr.user.avatar_url

        let prLink = pr.html_url

        let body = pr.body.map { body in
            let formatted = Document(parsing: body)
                .filterOutChildren(ofType: HTMLBlock.self)
                .format()
            return ">>> \(formatted)".unicodesPrefix(260)
        } ?? ""

        let description = """
        ### \(pr.title)

        \(body)
        """

        return .init(
            title: "[\(repo.uiName)] PR #\(number)".unicodesPrefix(256),
            description: description,
            url: prLink,
            color: .green,
            footer: .init(
                text: "By \(authorName)",
                icon_url: .exact(authorAvatarLink)
            )
        )
    }

    func onClosed() async throws {
        guard pr.base.ref == "main",
              let mergedBy = pr.merged_by,
              let bump = pr.knownLabels.first?.toBump()
        else { return }

        let previousRelease = try await getLastRelease()

        let tag = previousRelease.tag_name
        guard let (tagPrefix, previousVersion) = SemanticVersion.fromGithubTag(tag) else {
            throw Errors.tagDoesNotFollowSemVer(release: previousRelease, tag: tag)
        }

        guard let version = previousVersion.next(bump) else {
            throw Errors.cantBumpSemVer(version: previousVersion, bump: bump)
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
            payload: .init(content: """
            [\(repo.uiName)] \(version.description): \(pr.title)
            \(release.html_url)
            """
            )
        ).guardSuccess()
    }
}

private extension PRHandler {
    func getLastRelease() async throws -> Components.Schemas.release {
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

        let filteredReleases: [Components.Schemas.release] = releases.compactMap {
            release -> (Components.Schemas.release, SemanticVersion)? in
            if let (_, version) = SemanticVersion.fromGithubTag(release.tag_name) {
                return (release, version)
            }
            return nil
        }.filter { release, version -> Bool in
            if let majorVersion = Int(pr.base.ref) {
                // If the branch name is an integer, only include releases
                // for that major version.
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
            throw Errors.cantFindAnyRelease(latest: latest, releases: releases)
        }

        return release
    }

    private func getLatestRelease() async throws -> Components.Schemas.release? {
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
        mergedBy: Components.Schemas.nullable_simple_user,
        isPrerelease: Bool
    ) async throws -> Components.Schemas.release {
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

    func sendComment(release: Components.Schemas.release) async throws {
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
        let codeOwners = text.split(
            omittingEmptySubsequences: true,
            whereSeparator: \.isNewline
        ).map {
            $0.split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        }.flatMap {
            $0.dropFirst().map {
                String($0.dropFirst())
            }
        }
        return Set(codeOwners)
    }
}
