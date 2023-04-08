@testable import PennyBOT
import PennyModels

public struct FakePingsService: AutoPingsService {
    
    public init() { }
    
    public func exists(expression: Expression, forDiscordID id: String) async throws -> Bool {
        false
    }
    
    public func insert(_ expressions: [Expression], forDiscordID id: String) async throws {
        _ = try await FakePingsRepository().insert(
            expressions: expressions,
            forDiscordID: id
        )
    }
    
    public func remove(_ expressions: [Expression], forDiscordID id: String) async throws {
        _ = try await FakePingsRepository().remove(
            expressions: expressions,
            forDiscordID: id
        )
    }
    
    public func get(discordID id: String) async throws -> [Expression] {
        try await FakePingsRepository()
            .getAll()
            .items
            .filter { $0.value.contains(id) }
            .map(\.key)
    }
    
    public func getAll() async throws -> S3AutoPingItems {
        try await FakePingsRepository().getAll()
    }
}
