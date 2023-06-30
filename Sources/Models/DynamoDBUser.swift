import Foundation

public struct DynamoDBUser: Sendable, Codable {
    public let pk: String
    public let sk: String
    public let discordID: String?
    public let githubID: String?
    public let amountOfCoins: Int?
    public let coinEntries: [CoinEntry]?
    public let createdAt: Date
    
    public init(user: DynamoUser) {
        self.pk = "USER-\(user.id.uuidString)"
        self.sk = "CREATEDAT-\(user.createdAt)"
        if let discordID = user.discordID {
            self.discordID = "DISCORD-\(discordID)"
        } else {
            self.discordID = nil
        }
        self.githubID = user.githubID
        self.amountOfCoins = user.numberOfCoins
        self.coinEntries = user.coinEntries
        self.createdAt = user.createdAt
    }
}
