import PennyModels

protocol AutoPingsService {
    typealias Expression = S3AutoPingItems.Expression
    func exists(expression: Expression, forDiscordID id: String) async throws -> Bool
    func insert(_ expressions: [Expression], forDiscordID id: String) async throws
    func remove(_ expressions: [Expression], forDiscordID id: String) async throws
    func get(discordID id: String) async throws -> [Expression]
    func getAll() async throws -> S3AutoPingItems
}
