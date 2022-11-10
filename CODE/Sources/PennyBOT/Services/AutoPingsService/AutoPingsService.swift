import PennyModels

protocol AutoPingsService {
    func insert(_ text: String, forDiscordID id: String) async throws
    func remove(_ text: String, forDiscordID id: String) async throws
    func get(discordID id: String) async throws -> [S3AutoPingItems.Expression]
}
