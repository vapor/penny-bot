import SotoDynamoDB
import Foundation
import Models
import Extensions

struct DynamoUserRepository {
    enum Errors: Error, CustomStringConvertible {
        case discordUserNotFound(id: String)

        var description: String {
            switch self {
            case .discordUserNotFound(let id):
                return "Discord user with ID \(id) not found"
            }
        }
    }

    let db: DynamoDB
    let eventLoop: any EventLoop
    let logger: Logger

    let tableName = "penny-user-table"
    let discordIndex = "D-ID-GSI"
    let githubIndex = "GH-ID-GSI"

    init(db: DynamoDB, logger: Logger) {
        self.db = db
        self.eventLoop = db.eventLoopGroup.any()
        self.logger = logger
    }

    func createUser(_ user: DynamoDBUser) async throws {
        let input = DynamoDB.PutItemCodableInput(item: user, tableName: self.tableName)

        _ = try await db.putItem(input, logger: self.logger, on: self.eventLoop)
    }
    
    func updateUser(_ user: DynamoDBUser) async throws -> Void {
        let input = DynamoDB.UpdateItemCodableInput(
            key: ["id"],
            tableName: self.tableName,
            updateItem: user
        )
        _ = try await db.updateItem(input, logger: self.logger, on: self.eventLoop)
    }

    func getUser(discordID: UserSnowflake) async throws -> DynamoDBUser? {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s(discordID.rawValue)],
            indexName: discordIndex,
            keyConditionExpression: "\(DynamoDBUser.CodingKeys.discordID) = :v1",
            limit: 1,
            tableName: self.tableName
        )
        
        return try await queryUser(with: query)
    }

    func getUser(githubID: String) async throws -> DynamoDBUser? {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s(githubID)],
            indexName: githubIndex,
            keyConditionExpression: "\(DynamoDBUser.CodingKeys.githubID) = :v1",
            limit: 1,
            tableName: self.tableName
        )
        
        return try await queryUser(with: query)
    }

    /// Returns nil if user does not exist.
    private func queryUser(with query: DynamoDB.QueryInput) async throws -> DynamoDBUser? {
        try await db.query(
            query,
            type: DynamoDBUser.self,
            logger: self.logger,
            on: self.eventLoop
        ).items?.first
    }
}
