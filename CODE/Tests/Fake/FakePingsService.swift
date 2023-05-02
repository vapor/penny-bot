@testable import PennyBOT
import PennyModels
import DiscordModels

public struct FakePingsService: AutoPingsService {
    
    public init() { }
    
    public func exists(
        expression: Expression,
        forDiscordID id: Snowflake<DiscordUser>
    ) async throws -> Bool {
        false
    }
    
    public func insert(
        _ expressions: [Expression],
        forDiscordID id: Snowflake<DiscordUser>
    ) async throws {
        _ = try await FakePingsRepository().insert(
            expressions: expressions,
            forDiscordID: id.value
        )
    }
    
    public func remove(
        _ expressions: [Expression],
        forDiscordID id: Snowflake<DiscordUser>
    ) async throws {
        _ = try await FakePingsRepository().remove(
            expressions: expressions,
            forDiscordID: id.value
        )
    }
    
    public func get(discordID id: Snowflake<DiscordUser>) async throws -> [Expression] {
        try await FakePingsRepository()
            .getAll()
            .items
            .filter { $0.value.contains(id.value) }
            .map(\.key)
    }
    
    public func getAll() async throws -> S3AutoPingItems {
        try await FakePingsRepository().getAll()
    }
}
