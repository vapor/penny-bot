import DiscordBM
import GitHubAPI
import Logging
import Models
import Shared

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
            repoFullName: repo.fullName,
            branch: branch
        )
        for pr in prs {
            if pr.mergedAt == nil {
                logger.debug("PR is not merged yet", metadata: ["pr": "\(pr)"])
                continue
            }
            let user = try pr.user.requireValue()
            var usersToReceiveCoins = codeOwners.contains(user: user) ? [] : [user.id]

            let mergeCommitSHA = try pr.mergeCommitSha.requireValue()
            let commit = try (event.commits?.first { $0.id == mergeCommitSHA }).requireValue()
            let coAuthors = try await findCoAuthors(message: commit.message)

            usersToReceiveCoins +=
                coAuthors
                .filter({ !codeOwners.contains(login: $0.login) })
                .map(\.id)

            for userId in usersToReceiveCoins {
                try await self.giveCoin(userId: userId, pr: pr)
            }
        }
    }

    func getPRsRelatedToCommit() async throws -> [SimplePullRequest] {
        try await context.githubClient.reposListPullRequestsAssociatedWithCommit(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                commitSha: commitSHA
            )
        ).ok.body.json
    }

    func findCoAuthors(message: String) async throws -> [(login: String, id: Int64)] {
        let logins = message.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            guard line.hasPrefix("Co-authored-by: ") else { return nil }
            let loginAndEmailString = line.dropFirst(16)
            let loginAndEmail = loginAndEmailString.split(whereSeparator: \.isWhitespace)
            guard loginAndEmail.count == 2 else { return nil }
            let login = loginAndEmail[0]
            return String(login)
        }

        var coAuthors: [(login: String, id: Int64)] = []
        coAuthors.reserveCapacity(logins.count)
        for login in logins {
            let user = try await context.githubClient.usersGetByUsername(
                path: .init(username: login)
            ).ok.body.json
            let id =
                switch user {
                case let ._private(user): user.id
                case let ._public(user): user.id
                }
            coAuthors.append((login, id))
        }

        return coAuthors
    }

    func giveCoin(userId: Int64, pr: SimplePullRequest) async throws {
        logger.trace("Giving a coin", metadata: ["userId": .stringConvertible(userId)])

        guard
            let member = try await context.requester.getDiscordMember(
                githubID: "\(userId)"
            ), let discordID = member.userId
        else {
            logger.debug(
                "Found no Discord member for the GitHub user",
                metadata: [
                    "pr": "\(pr)"
                ]
            )
            return
        }

        /// Core-team members get no coins at all.
        if member.roles.contains(Constants.Roles.core.id) { return }

        let amount = 5
        let coinResponse = try await context.usersService.postCoin(
            with: .init(
                amount: amount,
                /// GuildID because this is automated.
                fromDiscordID: Snowflake(Constants.guildID),
                toDiscordID: discordID,
                source: .github,
                reason: .prMerge
            )
        )

        try await context.discordClient.createMessage(
            channelId: Constants.Channels.thanks.id,
            payload: .init(
                content: DiscordUtils.mention(id: discordID),
                embeds: [
                    .init(
                        description: """
                            Thanks for your contribution in [**\(pr.title)**](\(pr.htmlUrl)).
                            You now have \(amount) more \(Constants.ServerEmojis.coin.emoji) for a total of \(coinResponse.newCoinCount) \(Constants.ServerEmojis.coin.emoji)!
                            """,
                        color: .blue
                    ),
                    .init(
                        description: """
                            Want coins too? Link your GitHub account to take credit for your contributions.
                            Try `/github link` for more info, it's private.
                            """,
                        color: .green
                    ),
                ]
            )
        ).guardSuccess()
    }
}
