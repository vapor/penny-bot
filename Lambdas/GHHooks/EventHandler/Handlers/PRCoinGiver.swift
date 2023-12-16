import DiscordBM
import GitHubAPI
import Logging

/// Gives coins to GitHub users that have a linked Discord account, if their PR is merged.
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
        guard let branch = self.event.ref.extractHeadBranchFromRef(),
              branch.isPrimaryOrReleaseBranch(repo: repo)
        else { return }
        let prs = try await getPRsRelatedToCommit()
        if prs.isEmpty { return }
        let codeOwners = try await context.requester.getCodeOwners(
            repoFullName: repo.full_name,
            branch: branch
        )
        for pr in try await getPRsRelatedToCommit() {
            let user = try pr.user.requireValue()
            if pr.merged_at == nil ||
                codeOwners.contains(user: user) {
                continue
            }
            guard let member = try await context.requester.getDiscordMember(
                githubID: "\(user.id)"
            ), let discordID = member.user?.id else {
                logger.debug("Found no Discord member for the GitHub user", metadata: [
                    "pr": "\(pr)",
                ])
                continue
            }

            /// Core-team members get no coin at all.
            if member.roles.contains(Constants.Roles.core.id) { continue }

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
                    )]
                )
            ).guardSuccess()
        }
    }

    /// Should not contain any labels that indicate no need for a new issue.
    func needsNewIssue(pr: SimplePullRequest) -> Bool {
        Set(pr.knownLabels).intersection([.translationUpdate, .noTranslationNeeded]).isEmpty
    }

    func getPRsRelatedToCommit() async throws -> [SimplePullRequest] {
        try await context.githubClient.repos_list_pull_requests_associated_with_commit(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                commit_sha: commitSHA
            )
        ).ok.body.json
    }
}
