import GitHubAPI
import DiscordBM
import Logging
import Foundation

struct ReleaseReporter {

    enum Errors: Error, CustomStringConvertible {
        case noTagFoundMatchingReleaseTag(release: Release)

        var description: String {
            switch self {
            case let .noTagFoundMatchingReleaseTag(release):
                return "noTagFoundMatchingReleaseTag(\(release))"
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
        case .created:
            try await handleReleaseCreated()
        default:
            break
        }
    }

    func handleReleaseCreated() async throws {
        let tag = try await getTag()
        guard let lastRelatedPR = try await getLastPRRelatedToCommit(sha: tag.commit.sha) else {
            logger.debug("There were no related PRs for commit", metadata: [
                "tag": "\(tag)",
                "release": "\(release)"
            ])
            return
        }
        try await self.sendToDiscord(pr: lastRelatedPR)
    }

    func getTag() async throws -> Tag {
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

        guard let tag = json.first(where: { $0.name == release.tag_name }) else {
            throw Errors.noTagFoundMatchingReleaseTag(release: release)
        }

        return tag
    }

    func getLastPRRelatedToCommit(sha: String) async throws -> SimplePullRequest? {
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

        return json.first
    }

    func sendToDiscord(pr: SimplePullRequest) async throws {
        let body = pr.body.map { body -> String in
            let formatted = body.formatMarkdown(
                maxLength: 256,
                trailingParagraphMinLength: 128
            )
            return formatted.isEmpty ? "" : ">>> \(formatted)"
        } ?? ""

        let description = """
        ### \(pr.title)

        \(body)
        """
        let fullName = repo.full_name.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? repo.full_name
        let image = "https://opengraph.githubassets.com/\(UUID().uuidString)/\(fullName)/releases/tag/\(release.tag_name)"
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.release.id,
            payload: .init(
                embeds: [.init(
                    title: "[\(repo.uiName)] Release \(release.tag_name)".unicodesPrefix(256),
                    description: description,
                    url: release.html_url,
                    color: .cyan,
                    image: .init(url: .exact(image))
                )]
            )
        ).guardSuccess()
    }
}
