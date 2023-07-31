import GitHubAPI
import DiscordBM
import Logging

/// Sends a "Need translation" message for each PR in a push-commit that needs that.
struct PRCoinGiver {
    let context: HandlerContext
    let commitSHA: String
    let repo: Repository
    var event: GHEvent {
        context.event
    }
    var logger: Logger {
        context.logger
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.commitSHA = try context.event.after.requireValue()
        self.repo = try context.event.repository.requireValue()
    }

    func handle() async throws {
        guard event.ref == "refs/heads/\(repo.primaryBranch)" else {
            return
        }
        let prs = try await getPRsRelatedToCommit()
        if prs.isEmpty { return }
        let codeOwners = try await context.getCodeOwners(
            repoFullName: repo.full_name,
            primaryBranch: repo.primaryBranch
        )
        for pr in try await getPRsRelatedToCommit() {
            if pr.merged_at == nil { continue }
            if codeOwners.usernamesContain(user: pr.user) { continue }
            guard let member = try await context.getDiscordMember(githubID: "\(pr.user.id)"),
                  let discordID = member.user?.id else {
                logger.debug("Found no Discord member for the GitHub user", metadata: [
                    "pr": "\(pr)"
                ])
                continue
            }
            let amount = 3
            let coinResponse = try await context.usersService.postCoin(with: .init(
                amount: amount,
                /// GuildID because this is automated.
                fromDiscordID: Snowflake(Constants.guildID),
                toDiscordID: discordID,
                source: .github,
                reason: .prMerge
            ))

            try await context.discordClient.createMessage(
                channelId: Constants.Channels.thanks.id,
                payload: .init(
                    content: DiscordUtils.mention(id: discordID),
                    embeds: [.init(
                        description: """
                        Thanks for your contribution in [**\(pr.title)**](\(pr.html_url)).
                        You now have \(amount) more \(Constants.ServerEmojis.coin.emoji) for a total of \(coinResponse.newCoinCount) \(Constants.ServerEmojis.coin.emoji)!
                        """,
                        color: .blue
                    )],
                    allowed_mentions: .init(users: [discordID])
                )
            ).guardSuccess()
        }
    }

    /// Should not contain any labels that indicate no need for a new issue.
    func needsNewIssue(pr: SimplePullRequest) -> Bool {
        Set(pr.knownLabels).intersection([.translationUpdate, .noTranslationNeeded]).isEmpty
    }

    func getPRsRelatedToCommit() async throws -> [SimplePullRequest] {
        let response = try await context.githubClient.repos_list_pull_requests_associated_with_commit(
            .init(path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                commit_sha: commitSHA
            ))
        )

        guard case let .ok(ok) = response,
              case let .json(json) = ok.body else {
            throw Errors.httpRequestFailed(response: response)
        }

        return json
    }
}
