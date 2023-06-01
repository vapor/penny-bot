import SotoDynamoDB
import Foundation
import PennyModels
import PennyExtensions

struct DynamoUserRepository: UserRepository {
    
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

    /// Inserts a user with their first coin entry
    func insertUser(_ user: DynamoDBUser, coinEntry: CoinEntry) async throws -> Void {
        let user = DynamoDBUserWithEntries(dynamoDBUser: user, coinEntry: coinEntry)
        let input = DynamoDB.PutItemCodableInput(
            item: user,
            tableName: self.tableName
        )
        
        _ = try await db.putItem(input, logger: self.logger, on: self.eventLoop)
    }

    /// Updates the user and adds a coin for them
    func updateUser(_ user: DynamoDBUser, coinEntry: CoinEntry) async throws -> Void {
        DynamoDB.UpdateItemInput(
            attributeUpdates: <#T##[String : DynamoDB.AttributeValueUpdate]?#>,
            conditionalOperator: <#T##DynamoDB.ConditionalOperator?#>,
            conditionExpression: <#T##String?#>,
            expected: <#T##[String : DynamoDB.ExpectedAttributeValue]?#>,
            expressionAttributeNames: <#T##[String : String]?#>,
            expressionAttributeValues: <#T##[String : DynamoDB.AttributeValue]?#>,
            key: <#T##[String : DynamoDB.AttributeValue]#>,
            returnConsumedCapacity: <#T##DynamoDB.ReturnConsumedCapacity?#>,
            returnItemCollectionMetrics: <#T##DynamoDB.ReturnItemCollectionMetrics?#>,
            returnValues: <#T##DynamoDB.ReturnValue?#>,
            tableName: <#T##String#>,
            updateExpression: <#T##String?#>
        )
//        DynamoDB.UpdateItemCodableInput.init(
//            conditionExpression: <#T##String?#>,
//            expressionAttributeNames: <#T##[String : String]?#>,
//            key: <#T##[String]#>,
//            returnConsumedCapacity: <#T##DynamoDB.ReturnConsumedCapacity?#>,
//            returnItemCollectionMetrics: <#T##DynamoDB.ReturnItemCollectionMetrics?#>,
//            returnValues: <#T##DynamoDB.ReturnValue?#>,
//            tableName: <#T##String#>,
//            updateExpression: <#T##String?#>,
//            updateItem: <#T##_#>
//        )

        let input = DynamoDB.UpdateItemCodableInput(
            key: ["pk", "sk"],
            tableName: self.tableName,
            updateExpression: "ADD coinEntries :coinEntries",
            updateItem: user
        )
        
        _ = try await db.updateItem(input, logger: self.logger, on: self.eventLoop)
    }

    let userAttributes = [PennyTableAttributes]([.pk, .sk, .amountOfCoins, .data1])
        .map(\.rawValue)
        .joined(separator: ",")

    // MARK: - Retrieve
    func getUser(discord id: String) async throws -> User? {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s("DISCORD-\(id)")],
            indexName: discordIndex,
            keyConditionExpression: "data1 = :v1",
            limit: 1,
            projectionExpression: userAttributes,
            tableName: self.tableName
        )
        
        return try await queryUser(with: query)
    }
    
    func getUser(github id: String) async throws -> User? {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s("GITHUB-\(id)")],
            indexName: githubIndex,
            keyConditionExpression: "data2 = :v1",
            limit: 1,
            projectionExpression: userAttributes,
            tableName: self.tableName
        )
        
        return try await queryUser(with: query)
    }
    
    /// Returns nil if user does not exist.
    private func queryUser(with query: DynamoDB.QueryInput) async throws -> User? {
        let results = try await db.query(
            query,
            type: DynamoDBUser.self,
            logger: self.logger,
            on: self.eventLoop
        )
        guard let user = results.items?.first else { return nil }

        guard let userID = user.data1?.deletePrefix("DISCORD-")
                ?? user.data2?.deletePrefix("GITHUB-") else {
            return nil
        }
        let localUser = User(
            id: UUID(uuidString: user.pk.deletePrefix("USER-"))!,
            userID: userID,
            numberOfCoins: user.amountOfCoins ?? 0,
            createdAt: user.createdAt
        )
        
        return localUser
    }
    
    // MARK: - Link users
    func linkGithub(with discordId: String, _ githubId: String) async throws -> String {
        // TODO: Implement
        // Check if the users github already exists
        
        // If it exists, merge the 2 accounts
        
        // If the the given discordId already has a github account linked, overwrite the githubId
        
        // Delete the account that's not up-to-date
        abort()
    }
    
    func linkDiscord(with githubId: String, _ discordId: String) async throws -> String {
        // TODO: Implement
        // Check if the users discord already exists
        
        // If it exists, merge the 2 accounts
        
        // If the the given discordId already has a github account linked, overwrite the githubId
        
        // Delete the account that's not up-to-date
        abort()
    }
    
    private func mergeAccounts() async throws -> Bool {
        // TODO: Implement
        // Return true if the merge was successful
        abort()
    }
    
    private func deleteAccount() async throws -> Bool {
        // TODO: Implement
        // Return true if the deletion was successful
        abort()
    }
}

private enum PennyTableAttributes: String {
    case pk
    case sk
    case amountOfCoins
    case coinEntries
    case createdAt
    case data1
    case data2
}
