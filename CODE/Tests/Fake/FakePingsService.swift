@testable import PennyBOT
import PennyModels

public struct FakePingsService: AutoPingsService {
    
    public init() { }
    
    public func exists(text: String, forDiscordID id: String) async throws -> Bool {
        false
    }
    
    public func insert(_ texts: [String], forDiscordID id: String) async throws {
        _ = try await FakePingsRepository().insert(
            expressions: texts.map { .text($0) },
            forDiscordID: id
        )
    }
    
    public func remove(_ texts: [String], forDiscordID id: String) async throws {
        _ = try await FakePingsRepository().remove(
            expressions: texts.map { .text($0) },
            forDiscordID: id
        )
    }
    
    public func get(discordID id: String) async throws -> [S3AutoPingItems.Expression] {
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
