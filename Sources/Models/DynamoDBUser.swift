import Foundation

public struct DynamoDBUser: Sendable, Codable {
    public let pk: String
    public let sk: String
    public let data1: String?
    public let data2: String?
    public let amountOfCoins: Int?
    public let coinEntries: [CoinEntry]?
    public let createdAt: Date

    public init(
        pk: String,
        sk: String,
        data1: String?,
        data2: String?,
        amountOfCoins: Int?,
        coinEntries: [CoinEntry]?,
        createdAt: Date
    ) {
        self.pk = pk
        self.sk = sk
        self.data1 = data1
        self.data2 = data2
        self.amountOfCoins = amountOfCoins
        self.coinEntries = coinEntries
        self.createdAt = createdAt
    }
    
    public init(user: DynamoUser) {
        self.pk = "USER-\(user.id.uuidString)"
        self.sk = "CREATEDAT-\(user.createdAt)"
        if let discordID = user.discordID {
            self.data1 = "DISCORD-\(discordID)"
        } else {
            self.data1 = nil
        }
        self.data2 = user.githubID
        self.amountOfCoins = user.numberOfCoins
        self.coinEntries = user.coinEntries
        self.createdAt = user.createdAt
    }

    // Write a method that updates the user's data2 field to the githubID
    public func updateGithubID(with githubID: String) -> DynamoDBUser {
        DynamoDBUser(
            pk: self.pk,
            sk: self.sk,
            data1: self.data1,
            data2: githubID,
            amountOfCoins: self.amountOfCoins,
            coinEntries: self.coinEntries,
            createdAt: self.createdAt
        )
    }
}
