#if canImport(Darwin)
import Foundation
#else
@preconcurrency import Foundation
#endif

public struct DynamoDBUser: Sendable, Codable {
    public let id: UUID
    public var discordID: UserSnowflake
    public var githubID: String?
    public var coinCount: Int
    public let createdAt: Date

    public enum CodingKeys: String, CodingKey {
        case id
        case discordID
        case githubID
        case coinCount
        case createdAt

        public var description: String {
            self.rawValue
        }
    }

    private init(
        id: UUID,
        discordID: UserSnowflake,
        githubID: String?,
        coinCount: Int,
        createdAt: Date
    ) {
        self.id = id
        self.discordID = discordID
        self.githubID = githubID
        self.coinCount = coinCount
        self.createdAt = createdAt
    }

    public static func createNew(forDiscordID discordID: UserSnowflake) -> Self {
        DynamoDBUser(
            id: UUID(),
            discordID: discordID,
            githubID: nil,
            coinCount: 0,
            createdAt: Date()
        )
    }
}
