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
        #warning("Throw error id the item doesn't exist, so we can avoid sending all the data")
        var all = try await self.getAll()
        all.items[expression]?.remove(id)
        if all.items[expression]?.isEmpty == true {
            all.items[expression] = nil
        }
        try await self.save(items: all)
        return all
    }
    
    private var localPath: String {
        FileManager.default.currentDirectoryPath + "/Tests/Resources/autoPings.json"
    }
    
    func getAll() async throws -> S3AutoPingItems {
#if DEBUG
        if let data = FileManager.default.contents(atPath: localPath) {
            return try JSONDecoder().decode(S3AutoPingItems.self, from: data)
        } else {
            return S3AutoPingItems()
        }
#else
        #warning("compile error")
#endif
    }
    
    func save(items: S3AutoPingItems) async throws {
        let data = try JSONEncoder().encode(items)
        FileManager.default.createFile(atPath: localPath, contents: data)
    }
}
