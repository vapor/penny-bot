import Foundation

/// Used to transport coin-related user info.
public struct LambdaUser: Codable {
    public let id: UUID
    public let discordID: String?
    public let githubID: String?
    public var numberOfCoins: Int
    public var coinEntries: [CoinEntry]
    public let createdAt: Date
    
    public init(
        id: UUID,
        discordID: String?,
        githubID: String?,
        numberOfCoins: Int,
        coinEntries: [CoinEntry],
        createdAt: Date
    ) {
        self.id = id
        self.discordID = discordID
        self.githubID = githubID
        self.numberOfCoins = numberOfCoins
        self.coinEntries = coinEntries
        self.createdAt = createdAt
    }
    
    public mutating func addCoinEntry(_ entry: CoinEntry) {
        coinEntries.append(entry)
        numberOfCoins = numberOfCoins + entry.amount
    }
}
