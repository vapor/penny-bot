import Foundation
import SotoDynamoDB

enum DBError: Error {
    case invalidItem
    case tableNameNotFound
    case invalidRequest
    case invalidHandler
    case itemNotFound
}

public struct DynamoUserRepository: UserRepository {
    
    // MARK: - Properties
    let db: DynamoDB
    let tableName: String
    let eventLoop: EventLoop
    let logger: Logger
    
    let discordIndex = "GSI-1"
    let githubIndex = "GSI-2"
    
    init(db: DynamoDB, tableName: String, eventLoop: EventLoop, logger: Logger) {
        self.db = db
        self.tableName = tableName
        self.eventLoop = eventLoop
        self.logger = logger
    }
    
    // MARK: - Insert & Update
    func insertUser(_ user: DynamoDBUser) async throws -> Void {
        guard let dynamoUser = try? user.toDynamoDBObject() else {
            throw DBError.invalidItem
        }
        let input = DynamoDB.PutItemCodableInput(item: dynamoUser, tableName: self.tableName)
        
        _ = try await db.putItem(input, logger: self.logger, on: self.eventLoop)
    }
    
    func updateUser(_ user: DynamoDBUser) async throws -> Void {
        guard let dynamoUser = try? user.toDynamoDBObject() else {
            throw DBError.invalidItem
        }
        let input = DynamoDB.UpdateItemCodableInput(key: ["pk", "sk"], tableName: self.tableName, updateItem: dynamoUser)
        
        _ = try await db.updateItem(input, logger: self.logger, on: self.eventLoop)
    }
    
    // MARK: - Retrieve
    func getUser(discord id: String) async throws -> User {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s("\(id)")],
            indexName: discordIndex,
            keyConditionExpression: "data1 = :v1",
            limit: 1,
            tableName: self.tableName
        )
        let results = try await db.query(query, type: DynamoDBUser.self, logger: self.logger, on: self.eventLoop)
        guard let user = results.items?.first else {
            throw DBError.itemNotFound
        }
        
        let localUser = User(
            id: UUID(uuidString: String(user.pk.split(separator: "-")[1]))!,
            discordID: user.data1,
            githubID: user.data2,
            numberOfCoins: user.numberOfCoins,
            coinEntries: user.coinEntries,
            createdAt: user.createdAt
        )
        return localUser
    }
    
    func getUser(github id: String) async throws -> User {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s("\(id)")],
            indexName: githubIndex,
            keyConditionExpression: "data2 = :v1",
            limit: 1,
            tableName: self.tableName
        )
        let results = try await db.query(query, type: DynamoDBUser.self, logger: self.logger, on: self.eventLoop)
        guard let user = results.items?.first else {
            throw DBError.itemNotFound
        }
        
        let localUser = User(
            id: UUID(uuidString: String(user.pk.split(separator: "-")[1]))!,
            discordID: user.data1,
            githubID: user.data2,
            numberOfCoins: user.numberOfCoins,
            coinEntries: user.coinEntries,
            createdAt: user.createdAt
        )
        return localUser
    }
    
    // MARK: - Link users
    func linkGithub(with discordId: String, _ githubId: String) async throws -> Void {
        // TODO: Implement
        // Check if the users github already exists
        
        // If it exists, merge the 2 accounts
        
        // If the the given discordId already has a github account linked, overwrite the githubId
        
        // Delete the account that's not up-to-date
        
    }
    
    func linkDiscord(with githubId: String, _ discordId: String) async throws -> Void {
        // TODO: Implement
        // Check if the users discord already exists
        // If it exists, merge the 2 accounts
        
        // If the the given discordId already has a discord account linked, overwrite the githubId
        
        // Delete the account that's not up-to-date
        
    }
    
    private func mergeAccounts() async throws -> Void {
        
    }
    
    private func deleteAccount() async throws -> Void {
        
    }
}
