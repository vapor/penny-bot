
public enum UserRequest: Sendable, Codable {
    case addCoin(CoinEntryRequest)
    case getOrCreateUser(discordID: UserSnowflake)
    case getUser(githubID: String)
    case linkGitHubID(discordID: UserSnowflake, toGitHubID: String)

    public struct CoinEntryRequest: Sendable, Codable {
        public let amount: Int
        public let fromDiscordID: UserSnowflake
        public let toDiscordID: UserSnowflake
        public let source: CoinEntry.Source
        public let reason: CoinEntry.Reason

        public init(
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
