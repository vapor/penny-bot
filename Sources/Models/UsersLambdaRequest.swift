package import NewCodable

@JSONCodable
package enum UsersLambdaRequest: Sendable {
    case addCoin(CoinEntryRequest)
    case getOrCreateUser(discordID: UserSnowflake)
    case getUser(githubID: String)
    case linkGitHubID(discordID: UserSnowflake, toGitHubID: String)
    case unlinkGitHubID(discordID: UserSnowflake)

    @JSONCodable
    package struct CoinEntryRequest: Sendable {
        package let amount: Int
        package let fromDiscordID: UserSnowflake
        package let toDiscordID: UserSnowflake
        package let source: CoinEntry.Source
        package let reason: CoinEntry.Reason

        package init(
            amount: Int,
            fromDiscordID: UserSnowflake,
            toDiscordID: UserSnowflake,
            source: CoinEntry.Source,
            reason: CoinEntry.Reason
        ) {
            self.amount = amount
            self.fromDiscordID = fromDiscordID
            self.toDiscordID = toDiscordID
            self.source = source
            self.reason = reason
        }
    }
}
