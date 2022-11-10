import SotoDynamoDB
import Foundation
import PennyModels
import PennyExtensions

struct S3AutoPingsRepository: AutoPingsRepository {
    
    // MARK: - Properties
    let logger: Logger
    
    func insert(
        expression: S3AutoPingItems.Expression,
        forDiscordID id: String
    ) async throws -> S3AutoPingItems {
        var all = try await self.getAll()
        all.items[expression, default: []].insert(id)
        try await self.save(items: all)
        return all
    }
    
    func remove(
        expression: S3AutoPingItems.Expression,
        forDiscordID id: String
    ) async throws -> S3AutoPingItems {
        var all = try await self.getAll()
        all.items[expression]?.remove(id)
        if all.items[expression]?.isEmpty == true {
            all.items[expression] = nil
        }
        try await self.save(items: all)
        return all
    }
    
    func getAll() async throws -> S3AutoPingItems {
        /// Get the file from S3
        #warning("IMPLEMENT")
        fatalError()
    }
    
    func save(items: S3AutoPingItems) async throws {
        /// Save the file to S3
        #warning("IMPLEMENT")
        fatalError()
    }
}
