import SotoDynamoDB
import Foundation
import Models
import Extensions

struct DynamoUserRepository {
    
    // MARK: - Properties
    let db: DynamoDB
    let tableName: String
    let eventLoop: any EventLoop
    let logger: Logger
    
    let discordIndex = "GSI-1"
    let githubIndex = "GSI-2"
    
    init(db: DynamoDB, tableName: String, eventLoop: any EventLoop, logger: Logger) {
        self.db = db
        self.tableName = tableName
        self.eventLoop = eventLoop
        self.logger = logger
    }
    
    // MARK: - Insert & Update
    func insertUser(_ user: DynamoDBUser) async throws -> Void {
        let input = DynamoDB.PutItemCodableInput(item: user, tableName: self.tableName)
        
        _ = try await db.putItem(input, logger: self.logger, on: self.eventLoop)
    }
    
    func updateUser(_ user: DynamoDBUser) async throws -> Void {
        let input = DynamoDB.UpdateItemCodableInput(key: ["pk", "sk"], tableName: self.tableName, updateItem: user)
        
        _ = try await db.updateItem(input, logger: self.logger, on: self.eventLoop)
    }
    
    // MARK: - Retrieve
    func getUser(discord id: String) async throws -> DynamoUser? {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s("DISCORD-\(id)")],
            indexName: discordIndex,
            keyConditionExpression: "data1 = :v1",
            limit: 1,
            tableName: self.tableName
        )
        
        return try await queryUser(with: query)
    }
    
    func getUser(github id: String) async throws -> DynamoUser? {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s(id)],
            indexName: githubIndex,
            keyConditionExpression: "data2 = :v1",
            limit: 1,
            tableName: self.tableName
        )
        
        return try await queryUser(with: query)
    }
    
    /// Returns nil if user does not exist.
    private func queryUser(with query: DynamoDB.QueryInput) async throws -> DynamoUser? {
        let results = try await db.query(
            query,
            type: DynamoDBUser.self,
            logger: self.logger,
            on: self.eventLoop
        )
        guard let user = results.items?.first else {
            return nil
        }
        
        let localUser = DynamoUser(
            id: UUID(uuidString: user.pk.deletePrefix("USER-"))!,
            discordID: user.data1?.deletePrefix("DISCORD-"),
            githubID: user.data2,
            numberOfCoins: user.amountOfCoins ?? 0,
            coinEntries: user.coinEntries ?? [],
            createdAt: user.createdAt
        )
        
        return localUser
    }
    
    // MARK: - Link users

    func linkGithub(with discordID: String, _ githubID: String) async throws {
        logger.trace("Linking Github ID \(githubID) with Discord ID \(discordID)")
        enum Error: Swift.Error {
            case discordUserNotFound(id: String)

            var localizedDescription: String {
                switch self {
                case .discordUserNotFound(let id):
                    return "Discord user with ID \(id) not found"
                }
            }
        }
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s("DISCORD-\(discordID)")],
            indexName: discordIndex,
            keyConditionExpression: "data1 = :v1",
            limit: 1,
            tableName: self.tableName
        )

        guard let user = try await queryUser(with: query) else {
            throw Error.discordUserNotFound(id: discordID)
        }

        let updatedUser = DynamoDBUser(user: user)
            .updateGithubID(with: githubID)

        try await updateUser(updatedUser)
    }
}
