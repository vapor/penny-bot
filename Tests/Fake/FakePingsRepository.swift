import Foundation
import Models
import Repositories

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
            .matches("mongodb driver"): ["432065887202181142", "950695294906007573"],
            .matches("vapor"): ["432065887202181142"],
            .matches("penny"): ["950695294906007573"],
            .matches("discord"): ["432065887202181142"],
            .matches("discord-kit"): ["432065887202181142"],
            .matches("blog"): ["432065887202181142"],
            .contains("godb dr"): ["950695294906007573"],
            .contains("cord"): ["432065887202181142"],
        ])
    }
}
