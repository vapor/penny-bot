
public enum CoinRequest: Sendable, Codable {
    case addCoin(DiscordCoinEntry)
    case getUser(discordID: UserSnowflake)

    public struct DiscordCoinEntry: Sendable, Codable {
        public let amount: Int
        public let fromDiscordID: UserSnowflake
        public let toDiscordID: UserSnowflake
        public let source: CoinEntrySource
        public let reason: CoinEntryReason
        
        public init(
            amount: Int,
            fromDiscordID: UserSnowflake,
            toDiscordID: UserSnowflake,
            source: CoinEntrySource,
            reason: CoinEntryReason
        ) {
            self.amount = amount
            self.fromDiscordID = fromDiscordID
            self.toDiscordID = toDiscordID
            self.source = source
            self.reason = reason
        }
    }
}

public enum CoinEntrySource: String, Sendable, Codable {
    case discord
    case github
    case penny
}

public enum CoinEntryReason: String, Sendable, Codable {
    case userProvided
    case automationProvided
    case prSubmittedAndClosed
    case startedSponsoring
    case transferred
    case linkedProfile
}
