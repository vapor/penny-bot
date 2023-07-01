import Foundation

public struct DynamoDBUser: Sendable, Codable {
    public let pk: String
    public let sk: String
    public let data1: String?
    public let data2: String?
    public let amountOfCoins: Int?
    public let coinEntries: [CoinEntry]?
    public let createdAt: Date
    
    public init(user: DynamoUser) {
        self.pk = "USER-\(user.id.uuidString)"
        self.sk = "CREATEDAT-\(user.createdAt)"
        if let discordID = user.data1 {
            self.data1 = "DISCORD-\(discordID)"
        } else {
            self.data1 = nil
        }
        self.data2 = user.data2
        self.amountOfCoins = user.numberOfCoins
        self.coinEntries = user.coinEntries
        self.createdAt = user.createdAt
    }
}
