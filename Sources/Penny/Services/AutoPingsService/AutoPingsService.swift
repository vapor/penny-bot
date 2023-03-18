import Models

protocol AutoPingsService {
    func exists(text: String, forDiscordID id: String) async throws -> Bool
    func insert(_ texts: [String], forDiscordID id: String) async throws
    func remove(_ texts: [String], forDiscordID id: String) async throws
    func get(discordID id: String) async throws -> [S3AutoPingItems.Expression]
    func getAll() async throws -> S3AutoPingItems
}
