import Models

public protocol AutoPingsRepository {
    
    func insert(
        expressions: [S3AutoPingItems.Expression],
        forDiscordID id: String
    ) async throws -> S3AutoPingItems
    
    func remove(
        expressions: [S3AutoPingItems.Expression],
        forDiscordID id: String
    ) async throws -> S3AutoPingItems
    
    func getAll() async throws -> S3AutoPingItems
}
