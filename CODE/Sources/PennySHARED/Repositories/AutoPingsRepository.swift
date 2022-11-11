import PennyModels

public protocol AutoPingsRepository {
    
    // MARK: - Insert
    func insert(
        expressions: [S3AutoPingItems.Expression],
        forDiscordID id: String
    ) async throws -> S3AutoPingItems
    
    func remove(
        expressions: [S3AutoPingItems.Expression],
        forDiscordID id: String
    ) async throws -> S3AutoPingItems
    
    // MARK: - Retrieve
    func getAll() async throws -> S3AutoPingItems
}
