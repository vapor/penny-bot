import PennyModels
import DiscordBM

protocol AutoPingsService {
    typealias Expression = S3AutoPingItems.Expression
    func exists(expression: Expression, forDiscordID id: Snowflake<DiscordUser>) async throws -> Bool
    func insert(_ expressions: [Expression], forDiscordID id: Snowflake<DiscordUser>) async throws
    func remove(_ expressions: [Expression], forDiscordID id: Snowflake<DiscordUser>) async throws
    func get(discordID id: Snowflake<DiscordUser>) async throws -> [Expression]
    func getAll() async throws -> S3AutoPingItems
}
