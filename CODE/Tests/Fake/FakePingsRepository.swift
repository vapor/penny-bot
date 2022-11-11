import Foundation
import PennyModels
import PennyRepositories

public struct FakePingsRepository: AutoPingsRepository {
    
    public init() { }
    
    public func insert(
        expressions: [S3AutoPingItems.Expression],
        forDiscordID id: String
    ) async throws -> S3AutoPingItems {
        var all = try await self.getAll()
        for expression in expressions {
            all.items[expression, default: []].insert(id)
        }
        return all
    }
    
    public func remove(
        expressions: [S3AutoPingItems.Expression],
        forDiscordID id: String
    ) async throws -> S3AutoPingItems {
        var all = try await self.getAll()
        for expression in expressions {
            all.items[expression]?.remove(id)
            if all.items[expression]?.isEmpty == true {
                all.items[expression] = nil
            }
        }
        return all
    }
    
    public func getAll() async throws -> S3AutoPingItems {
        S3AutoPingItems(items: [
            .text("mongo"): ["<@21939123912932193>", "<@4912300012398455>"],
            .text("vapor"): ["<@21939123912932193>"],
            .text("penny"): ["<@4912300012398455>"]
        ])
    }
}
