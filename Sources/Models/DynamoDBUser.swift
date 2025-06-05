#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

package struct DynamoDBUser: Sendable, Codable {
    package let id: UUID
    package var discordID: UserSnowflake
    package var githubID: String?
    package var coinCount: Int
    package let createdAt: Date

    package enum CodingKeys: String, CodingKey {
        case id
        case discordID
        case githubID
        case coinCount
        case createdAt

        package var description: String {
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

    package static func createNew(forDiscordID discordID: UserSnowflake) -> Self {
        DynamoDBUser(
            id: UUID(),
            discordID: discordID,
            githubID: nil,
            coinCount: 0,
            createdAt: Date()
        )
    }
}
