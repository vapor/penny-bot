import PennyModels

public protocol AutoPingsRepository {
    
    // MARK: - Insert
    func insertText(_ text: String, forDiscordID id: String) async throws
    func removeText(_ text: String, forDiscordID id: String) async throws
    
    // MARK: - Retrieve
    func get(discordID id: String) async throws -> DynamoDBAutoPingItem
    func getAll() async throws -> [DynamoDBAutoPingItem]
}
