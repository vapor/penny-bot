import Foundation

public struct DynamoDBUser: Sendable, Codable {

    public enum Kind {
        case discord
        case github
    }

    public let pk: String
    public let sk: String
    public let data1: String?
    public let data2: String?
    public let amountOfCoins: Int?
    public let createdAt: Date
    
    public init(user: User, type: Kind) {
        self.pk = "USER-\(user.id.uuidString)"
        self.sk = "CREATEDAT-\(user.createdAt)"
        switch type {
        case .discord:
            self.data1 = "DISCORD-\(user.userID)"
            self.data2 = nil
        case .github:
            self.data1 = nil
            self.data2 = "GITHUB-\(user.userID)"
        }
        self.amountOfCoins = user.numberOfCoins
        self.createdAt = user.createdAt
    }
}

public struct DynamoDBUserWithEntries: Sendable, Codable {
    public let pk: String
    public let sk: String
    public let data1: String?
    public let data2: String?
    public let amountOfCoins: Int?
    public let coinEntries: [CoinEntry]?
    public let createdAt: Date

    public init(dynamoDBUser user: DynamoDBUser, coinEntry: CoinEntry) {
        self.pk = user.pk
        self.sk = user.sk
        self.data1 = user.data1
        self.data2 = user.data2
        self.amountOfCoins = user.amountOfCoins
        self.createdAt = user.createdAt

        self.coinEntries = [coinEntry]
    }
}
