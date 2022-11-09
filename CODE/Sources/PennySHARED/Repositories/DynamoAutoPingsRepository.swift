import SotoDynamoDB
import Foundation
import PennyModels
import PennyExtensions

struct DynamoAutoPingsRepository: AutoPingsRepository {
    
    // MARK: - Properties
    let db: DynamoDB
    let tableName: String
    let eventLoop: any EventLoop
    let logger: Logger
    
    init(db: DynamoDB, tableName: String, eventLoop: any EventLoop, logger: Logger) {
        self.db = db
        self.tableName = tableName
        self.eventLoop = eventLoop
        self.logger = logger
    }
    
    func insertText(_ text: String, forDiscordID id: String) async throws {
        if var current = try await queryOne(discordId: id) {
            if current.texts.contains(text) {
                throw DBError.alreadyAvailable
            } else {
                current.texts.append(text)
            }
            let input = DynamoDB.UpdateItemCodableInput(
                key: ["discordUserID"],
                tableName: self.tableName,
                updateItem: current
            )
            _ = try await db.updateItem(input, logger: self.logger, on: self.eventLoop)
        } else {
            let new = DynamoDBAutoPingItem(discordUserID: id, texts: [text])
            let input = DynamoDB.PutItemCodableInput(item: new, tableName: self.tableName)
            _ = try await db.putItem(input, logger: self.logger, on: self.eventLoop)
        }
    }
    
    func removeText(_ text: String, forDiscordID id: String) async throws {
        var item = try await get(discordID: id)
        item.texts = item.texts.filter({ $0 == text })
        let input = DynamoDB.UpdateItemCodableInput(
            key: ["discordUserID"],
            tableName: self.tableName,
            updateItem: item
        )
        _ = try await db.updateItem(input, logger: self.logger, on: self.eventLoop)
    }
    
    func get(discordID id: String) async throws -> DynamoDBAutoPingItem {
        let item = try await queryOne(discordId: id)
        guard let item = item else {
            throw DBError.itemNotFound
        }
        
        return item
    }
    
    func getAll() async throws -> [DynamoDBAutoPingItem] {
        let query = DynamoDB.QueryInput(tableName: self.tableName)
        
        let results = try await db.query(
            query,
            type: DynamoDBAutoPingItem.self,
            logger: self.logger,
            on: self.eventLoop
        )
        guard let items = results.items,
              !items.isEmpty else {
            throw DBError.noItemsFound
        }
        
        return items
    }
    
    func queryOne(discordId id: String) async throws -> DynamoDBAutoPingItem? {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s(id)],
            keyConditionExpression: "discordUserID = :v1",
            tableName: self.tableName
        )
        
        let results = try await db.query(
            query,
            type: DynamoDBAutoPingItem.self,
            logger: self.logger,
            on: self.eventLoop
        )
        
        return results.items?.first
    }
}
