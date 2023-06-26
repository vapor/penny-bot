import Models
import AsyncHTTPClient
import Foundation
import Logging
import DiscordBM
import NIOHTTP1

actor DefaultPingsService: AutoPingsService {
    
    var httpClient: HTTPClient!
    var logger = Logger(label: "DefaultPingsService")
    
    /// Use `getAll()` to retrieve.
    var _cachedItems: S3AutoPingItems?
    var resetItemsTask: Task<(), Never>?

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    private init() { }
    
    static let shared = DefaultPingsService()
    
    func initialize(httpClient: HTTPClient) {
        self.httpClient = httpClient
        self.setUpResetItemsTask()
        self.getFreshItemsForCache()
    }
    
    func exists(
        expression: Expression,
        forDiscordID id: UserSnowflake
    ) async throws -> Bool {
        try await self.getAll().items[expression]?.contains(id.rawValue) ?? false
    }
    
    func insert(
        _ expressions: [Expression],
        forDiscordID id: UserSnowflake
    ) async throws {
        try await self.send(
            pathParameter: "users",
            method: .PUT,
            pingRequest: .init(discordID: id.rawValue, expressions: expressions)
        )
    }
    
    func remove(
        _ expressions: [Expression],
        forDiscordID id: UserSnowflake
    ) async throws {
        try await self.send(
            pathParameter: "users",
            method: .DELETE,
            pingRequest: .init(discordID: id.rawValue, expressions: expressions)
        )
    }
    
    func get(discordID id: UserSnowflake) async throws -> [Expression] {
        try await self.getAll()
            .items
            .filter { $0.value.contains(id.rawValue) }
            .map(\.key)
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
    
    @discardableResult
    func send(
        pathParameter: String,
        method: HTTPMethod,
        pingRequest: AutoPingsRequest?
    ) async throws -> S3AutoPingItems {
        let url = Constants.apiBaseUrl + "/auto-pings/" + pathParameter
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
        
        guard (200..<300).contains(response.status.code) else {
            let collected = try? await response.body.collect(upTo: 1 << 16)
            let body = collected.map { String(buffer: $0) } ?? "nil"
            logger.error( "Pings-service failed", metadata: [
                "status": "\(response.status)",
                "headers": "\(response.headers)",
                "body": "\(body)",
            ])
            throw ServiceError.badStatus(response.status)
        }
        
        let body = try await response.body.collect(upTo: 1 << 24)
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
