#if canImport(Darwin)
import Foundation
#else
@preconcurrency import Foundation
#endif
import Models
import AsyncHTTPClient
import Logging
import DiscordBM
import NIOHTTP1

actor DefaultPingsService: AutoPingsService {
    
    let httpClient: HTTPClient = .shared
    var logger = Logger(label: "DefaultPingsService")
    
    /// Use `getAll()` to retrieve.
    var _cachedItems: S3AutoPingItems?
    /// `[ExpressionHash: Expression]`
    var _cachedExpressionsHashTable: [Int: Expression]?
    var resetItemsTask: Task<(), Never>?

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    init() {
        Task {
            await self.setUpResetItemsTask()
            await self.getFreshItemsForCache()
        }
    }

    func exists(
        expression: Expression,
        forDiscordID id: UserSnowflake
    ) async throws -> Bool {
        try await self.getAll().items[expression]?.contains(id) ?? false
    }
    
    func insert(
        _ expressions: [Expression],
        forDiscordID id: UserSnowflake
    ) async throws {
        try await self.send(
            pathParameter: "users",
            method: .PUT,
            pingRequest: .init(discordID: id, expressions: expressions)
        )
    }
    
    func remove(
        _ expressions: [Expression],
        forDiscordID id: UserSnowflake
    ) async throws {
        try await self.send(
            pathParameter: "users",
            method: .DELETE,
            pingRequest: .init(discordID: id, expressions: expressions)
        )
    }
    
    func get(discordID id: UserSnowflake) async throws -> [Expression] {
        try await self.getAll()
            .items
            .filter { $0.value.contains(id) }
            .map(\.key)
    }

    func getExpression(hash: Int) async throws -> Expression? {
        try await getAllExpressionsHashTable()[hash]
    }

    func getAll() async throws -> S3AutoPingItems {
        if let cachedItems = _cachedItems {
            return cachedItems
        } else {
            return try await self.send(
                pathParameter: "all",
                method: .GET,
                pingRequest: nil
            )
        }
    }

    func getAllExpressionsHashTable() async throws -> [Int: Expression] {
        if let cachedItems = _cachedExpressionsHashTable {
            return cachedItems
        } else {
            try await self.send(
                pathParameter: "all",
                method: .GET,
                pingRequest: nil
            )
            return _cachedExpressionsHashTable ?? [:]
        }
    }

    @discardableResult
    func send(
        pathParameter: String,
        method: HTTPMethod,
        pingRequest: AutoPingsRequest?
    ) async throws -> S3AutoPingItems {
        let url = Constants.apiBaseURL + "/auto-pings/" + pathParameter
        var request = HTTPClientRequest(url: url)
        request.method = method
        if let pingRequest {
            request.headers.add(name: "Content-Type", value: "application/json")
            let data = try encoder.encode(pingRequest)
            request.body = .bytes(data)
        }
        let response = try await httpClient.execute(
            request,
            timeout: .seconds(60),
            logger: self.logger
        )
        logger.trace("HTTP head", metadata: ["response": "\(response)"])
        
        guard 200..<300 ~= response.status.code else {
            let collected = try? await response.body.collect(upTo: 1 << 16) /// 64 KiB
            let body = collected.map { String(buffer: $0) } ?? "nil"
            logger.error( "Pings-service failed", metadata: [
                "status": "\(response.status)",
                "headers": "\(response.headers)",
                "body": "\(body)",
            ])
            throw ServiceError.badStatus(response.status)
        }
        
        let body = try await response.body.collect(upTo: 1 << 24) /// 16 MiB
        let items = try decoder.decode(S3AutoPingItems.self, from: body)
        freshenCache(items)
        resetItemsTask?.cancel()
        return items
    }
    
    private func freshenCache(_ new: S3AutoPingItems) {
        logger.trace("Will refresh auto-pings cache", metadata: [
            "new": .stringConvertible(new.items)
        ])
        self._cachedItems = new
        self._cachedExpressionsHashTable = Dictionary(
            uniqueKeysWithValues: new.items.map({ ($0.key.hashValue, $0.key) })
        )
        self.resetItemsTask?.cancel()
    }

    private func getFreshItemsForCache() {
        Task {
            do {
                /// To freshen the cache
                _ = try await self.send(
                    pathParameter: "all",
                    method: .GET,
                    pingRequest: nil
                )
            } catch {
                logger.report("Couldn't automatically freshen auto-pings cache", error: error)
            }
        }
    }

    private func setUpResetItemsTask() {
        self.resetItemsTask?.cancel()
        self.resetItemsTask = Task {
            /// Force-refresh cache after 6 hours of no activity
            if (try? await Task.sleep(for: .seconds(60 * 60 * 6))) != nil {
                self._cachedItems = nil
                self.getFreshItemsForCache()
                self.setUpResetItemsTask()
            } else {
                /// If canceled, set up the task again.
                /// This way, the functions above can cancel this when they've got fresh items
                /// and this will just reschedule itself for a later time.
                self.setUpResetItemsTask()
            }
        }
    }
}
