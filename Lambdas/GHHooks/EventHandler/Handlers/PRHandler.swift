import DiscordBM
import SwiftSemver

struct PRHandler {

    enum Errors: Error, CustomStringConvertible {
        case httpRequestFailed(response: Any, file: String = #filePath, line: UInt = #line)
        case tagDoesNotFollowSemVer(release: Components.Schemas.release, tag: String)
        case cantBumpSemVer(version: SemanticVersion, bump: SemVerBump)

        var description: String {
            switch self {
            case let .httpRequestFailed(response, file, line):
                return "httpRequestFailed(response: \(response), file: \(file), line: \(line))"
            case let .tagDoesNotFollowSemVer(release, tag):
                return "tagDoesNotFollowSemVer(release: \(release), tag: \(tag))"
            case let .cantBumpSemVer(version, bump):
                return "cantBumpSemVer(version: \(version), bump: \(bump))"
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
    var repoName: String {
        repo.organization?.login == "vapor" ? repo.name : repo.full_name
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
        default: break
        }
    }

    func onOpened() async throws {
        let creatorName = pr.user.login
        let creatorLink = pr.user.html_url

        let prLink = pr.html_url

        let body = pr.body == nil ? "" : "\n\n>>> \(pr.body!)".unicodesPrefix(264)

        let description = """
        ### \(pr.title)

        **By [\(creatorName)](\(creatorLink))**
        \(body)
        """

        try await context.discordClient.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(embeds: [.init(
                title: "[\(repoName)] PR #\(number)".unicodesPrefix(256),
                description: description,
                url: prLink,
                color: .green
            )])
        ).guardSuccess()
    }

    func onClosed() async throws {
        guard pr.base.ref == "main",
              let mergedBy = pr.merged_by,
              let bump = pr.knownLabels.first?.toBump()
        else { return }

        let previousRelease = try await getLatestRelease()

        var tag = previousRelease.tag_name
        var tagPrefix = ""
        /// For tags like "v1.0.0" which start with a alphabetical character.
        if tag.first?.isNumber == false {
            tagPrefix = String(tag.removeFirst())
        }
        guard let previousVersion = SemanticVersion(string: tag) else {
            throw Errors.tagDoesNotFollowSemVer(release: previousRelease, tag: tag)
        }

        guard let version = previousVersion.next(bump) else {
            throw Errors.cantBumpSemVer(version: previousVersion, bump: bump)
        }
        let versionDescription = tagPrefix + version.description

        let acknowledgment: String
        if pr.user.login == mergedBy.login {
            acknowledgment = "This patch was authored and released by @\(pr.user.login)."
        } else {
            acknowledgment = "This patch was authored by @\(pr.user.login) and released by @\(mergedBy.login)."
        }

        let release = try await makeNewRelease(
            version: versionDescription,
            isPrerelease: !version.prereleaseIdentifiers.isEmpty,
            acknowledgment: acknowledgment
        )

        try await sendComment(release: release)

        /// FXIME: change channel to `.release` after tests.
        /// Give send-message perm to Penny for the release channel.
        /// Repair tests.
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(embeds: [.init(
                title: "[\(repoName)] \(release.tag_name)",
                description: """
                >>> \(pr.title)

                \(release.html_url)
                """,
                color: .blue
            )])
        ).guardSuccess()
    }

    func getLatestRelease() async throws -> Components.Schemas.release {
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

        throw Errors.httpRequestFailed(response: response)
    }

    func makeNewRelease(
        version: String,
        isPrerelease: Bool,
        acknowledgment: String
    ) async throws -> Components.Schemas.release {
        let response = try await context.githubClient.repos_create_release(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            ),
            body: .json(.init(
                tag_name: version.description,
                target_commitish: pr.base.ref,
                name: pr.title,
                body: """
                ###### _\(acknowledgment)_

                \(pr.body ?? "")
                """,
                draft: false,
                prerelease: isPrerelease,
                make_latest: ._true
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
        // '"Issues" create comment', but works for PRs too. Didn't find an endpoint for PRs.
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
}
