import Foundation
import SotoDynamoDB

struct DynamoDBUser: Codable {
    let pk: String
    let sk: String
    let data1: String?
    let data2: String?
    let numberOfCoins: Int
    let coinEntries: [CoinEntry]
    let createdAt: Date
    
    init(user: User) {
        self.pk = "USER-\(user.id.uuidString)"
        self.sk = "NUMBER_OF_COINS-\(user.numberOfCoins)"
        if let discordID = user.discordID {
            self.data1 = "DISCORD-\(discordID)"
        } else {
            self.data1 = nil
        }
        if let githubID = user.githubID {
            self.data2 = "GITHUB-\(githubID)"
        } else {
            self.data2 = nil
        }
        self.numberOfCoins = user.numberOfCoins
        self.coinEntries = user.coinEntries
        self.createdAt = user.createdAt
    }
}

extension DynamoDBUser {
    func toDynamoDBObject() throws -> [String: DynamoDB.AttributeValue] {
        return try DynamoDBEncoder().encode(self)
    }
    
    func fromDynamoDBObject(_ userAttributes: [String: DynamoDB.AttributeValue]) throws -> DynamoDBUser {
        return try DynamoDBDecoder().decode(DynamoDBUser.self, from: userAttributes)
    }
}
