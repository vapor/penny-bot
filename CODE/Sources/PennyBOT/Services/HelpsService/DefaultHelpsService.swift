import PennyRepositories
import PennyModels
import AsyncHTTPClient
import Foundation
import Logging
import NIOHTTP1

actor DefaultHelpsService: HelpsService {

    var httpClient: HTTPClient!
    var logger = Logger(label: "DefaultPingsService")

    /// Use `getAll()` to retrieve.
    var _cachedItems: [String: String]?
    var resetItemsTask: Task<(), Never>?

    private init() { }

    static let shared = DefaultHelpsService()

    func initialize(httpClient: HTTPClient) {
        self.httpClient = httpClient
        self.setUpResetItemsTask()
        self.getFreshItemsForCache()
    }
    
    func insert(name: String, value: String) async throws {
        try await self.send(request: .add(name: name, value: value))
    }

    func remove(name: String) async throws {
        try await self.send(request: .remove(name: name))
    }

    func get(name: String) async throws -> String? {
        try await self.getAll()[name]
    }

    func getAll() async throws -> [String: String] {
        if let cachedItems = _cachedItems {
            return cachedItems
        } else {
            return try await self.send(request: .all)
        }
    }

    @discardableResult
    func send(request helpsRequest: HelpsRequest) async throws -> [String: String] {
        let url = Constants.apiBaseUrl + "/helps"
        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try JSONEncoder().encode(helpsRequest)
        request.body = .bytes(data)
        let response = try await httpClient.execute(
            request,
            timeout: .seconds(60),
            logger: self.logger
        )
        logger.trace("HTTP head", metadata: ["response": "\(response)"])

        guard (200..<300).contains(response.status.code) else {
            let collected = try? await response.body.collect(upTo: 1 << 16)
            let body = collected.map { String(buffer: $0) } ?? "nil"
            logger.error("Helps-service failed", metadata: [
                "status": "\(response.status)",
                "headers": "\(response.headers)",
                "body": "\(body)",
            ])
            throw ServiceError.badStatus(response.status)
        }

        let body = try await response.body.collect(upTo: 1 << 24)
        let items = try JSONDecoder().decode([String: String].self, from: body)
        freshenCache(items)
        resetItemsTask?.cancel()
        return items
    }

    private func freshenCache(_ new: [String: String]) {
        logger.trace("Will refresh helps cache", metadata: [
            "new": .stringConvertible(new)
        ])
        self._cachedItems = new
        self.resetItemsTask?.cancel()
    }

    private func getFreshItemsForCache() {
        Task {
            do {
                /// To freshen the cache
                _ = try await self.send(request: .all)
            } catch {
                logger.report("Couldn't automatically freshen helps cache", error: error)
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
