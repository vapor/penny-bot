import GitHubAPI
import DiscordBM
import Logging
import Foundation

struct ReleaseReporter {

    enum Errors: Error, CustomStringConvertible {
        case noPreviousTagFound(release: Release, tags: [Tag])

        var description: String {
            switch self {
            case let .noPreviousTagFound(release, tags):
                return "noPreviousTagFound(release: \(release), tags: \(tags))"
            }
        }
    }

    let context: HandlerContext
    let release: Release
    let repo: Repository
    var logger: Logger {
        context.logger
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.release = try context.event.release.requireValue()
        self.repo = try context.event.repository.requireValue()
    }

    func handle() async throws {
        let action = try context.event.action
            .flatMap({ Release.Action(rawValue: $0) })
            .requireValue()
        switch action {
        case .published:
            try await handleReleasePublished()
        default:
            break
        }
    }

    func handleReleasePublished() async throws {
        let relatedPRs = try await self.getPRsRelatedToRelease()
        if relatedPRs.isEmpty {
            try await sendToDiscordWithRelease()
        } else if relatedPRs.count == 1 || release.author.id == Constants.GitHub.userID {
            /// If there is only 1 PR or if Penny released this, then just mention the last PR.
            try await self.sendToDiscord(pr: relatedPRs[0])
        } else {
            /// If it was a manual release, use the release for Discord message.
            try await sendToDiscordWithRelease()
        }
    }

    func getTagBefore() async throws -> String {
        let response = try await context.githubClient.repos_list_tags(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            ))
        )

        guard case let .ok(ok) = response,
              case let .json(json) = ok.body else {
            throw GHHooksLambda.Errors.httpRequestFailed(response: response)
        }

        if let releaseIdx = json.firstIndex(where: { $0.name == release.tag_name }),
           json.count > releaseIdx {
            return json[releaseIdx + 1].name
        }

        throw Errors.noPreviousTagFound(
            release: release,
            tags: json
        )
    }


    func getPRsRelatedToRelease() async throws -> [SimplePullRequest] {
        let tagBefore = try await getTagBefore()
        let commits = try await getCommitsInRelease(tagBefore: tagBefore)
        var prs = [SimplePullRequest]()
        prs.reserveCapacity(commits.count)

        for commit in commits {
            let newPRs = try await getPRsRelatedToCommit(sha: commit.sha)
            prs.append(contentsOf: newPRs)
        }

        return prs
    }

    func getCommitsInRelease(tagBefore: String) async throws -> [Commit] {
        let response = try await context.githubClient.repos_compare_commits(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                basehead: "\(tagBefore)...\(release.tag_name)"
            ))
        )

        guard case let .ok(ok) = response,
              case let .json(json) = ok.body else {
            throw GHHooksLambda.Errors.httpRequestFailed(response: response)
        }

        return json.commits.reversed()
    }

    func getPRsRelatedToCommit(sha: String) async throws -> [SimplePullRequest] {
        let response = try await context.githubClient.repos_list_pull_requests_associated_with_commit(
            .init(path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                commit_sha: sha
            ))
        )

        guard case let .ok(ok) = response,
              case let .json(json) = ok.body else {
            throw GHHooksLambda.Errors.httpRequestFailed(response: response)
        }

        return json
    }



    func sendToDiscord(pr: SimplePullRequest) async throws {
        let body = pr.body.map { body -> String in
            body.formatMarkdown(
                maxLength: 256,
                trailingParagraphMinLength: 96
            )
        } ?? ""

        let description = try await context.renderClient.ticketReport(title: pr.title, body: body)

        let fullName = repo.full_name.urlPathEncoded()
        let image = "https://opengraph.githubassets.com/\(UUID().uuidString)/\(fullName)/releases/tag/\(release.tag_name)"

        try await self.sendToDiscord(embed: .init(
            title: "[\(repo.uiName)] Release \(release.tag_name)".unicodesPrefix(256),
            description: description,
            url: release.html_url,
            color: .cyan,
            image: .init(url: .exact(image))
        ))
    }

    func sendToDiscordWithRelease() async throws {
        let description = release.body.map { body -> String in
            let preferredContent = body.contentsOfHeading(
                named: "What's Changed"
            ) ?? body
            let formatted = preferredContent.formatMarkdown(
                maxLength: 384,
                trailingParagraphMinLength: 96
            )
            return formatted.isEmpty ? "" : ">>> \(formatted)"
        } ?? ""

        let fullName = repo.full_name.urlPathEncoded()
        let image = "https://opengraph.githubassets.com/\(UUID().uuidString)/\(fullName)/releases/tag/\(release.tag_name)"

        try await self.sendToDiscord(embed: .init(
            title: "[\(repo.uiName)] Release \(release.tag_name)".unicodesPrefix(256),
            description: description,
            url: release.html_url,
            color: .cyan,
            image: .init(url: .exact(image))
        ))
    }

    func sendToDiscord(embed: Embed) async throws {
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.release.id,
            payload: .init(
                embeds: [embed]
            )
        ).guardSuccess()
    }
}
