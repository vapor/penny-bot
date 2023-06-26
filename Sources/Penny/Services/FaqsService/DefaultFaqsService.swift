import Models
import AsyncHTTPClient
import Foundation
import Logging
import NIOHTTP1

actor DefaultFaqsService: FaqsService {

    var httpClient: HTTPClient!
    var logger = Logger(label: "DefaultPingsService")

    /// Use `getAll()` to retrieve.
    var _cachedItems: [String: String]?
    /// Use `getAllNamesHashTable()` to retrieve.
    /// `[NameHash: Name]`
    var _cachedNamesHashTable: [Int: String]?
    var resetItemsTask: Task<(), Never>?

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    private init() { }

    static let shared = DefaultFaqsService()

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

    func getName(hash: Int) async throws -> String? {
        try await self.getAllNamesHashTable()[hash]
    }

    func getAll() async throws -> [String: String] {
        if let cachedItems = _cachedItems {
            return cachedItems
        } else {
            try await self.send(request: .all)
            return _cachedItems ?? [:]
        }
    }

    func getAllNamesHashTable() async throws -> [Int: String] {
        if let cachedItems = _cachedNamesHashTable {
            return cachedItems
        } else {
            try await self.send(request: .all)
            return _cachedNamesHashTable ?? [:]
        }
    }

    /// Must "freshenCache" if it didn't throw an error.
    func send(request faqsRequest: FaqsRequest) async throws {
        let url = Constants.apiBaseUrl + "/faqs"
        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try encoder.encode(faqsRequest)
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
            logger.error("Faqs-service failed", metadata: [
                "status": "\(response.status)",
                "headers": "\(response.headers)",
                "body": "\(body)",
            ])
            throw ServiceError.badStatus(response.status)
        }

        let body = try await response.body.collect(upTo: 1 << 24)
        let items = try decoder.decode([String: String].self, from: body)
        freshenCache(items)
        resetItemsTask?.cancel()
    }

    private func freshenCache(_ new: [String: String]) {
        logger.trace("Will refresh faqs cache", metadata: [
            "new": .stringConvertible(new)
        ])
        self._cachedItems = new
        /// There is an insignificant chance that there will be duplicate hashes for different keys,
        /// in which case i'd rather deal with a crash, than some buggy behavior.
        self._cachedNamesHashTable = Dictionary(
            uniqueKeysWithValues: new.map({ ($0.key.hash, $0.key) })
        )
        self.resetItemsTask?.cancel()
    }

    private func getFreshItemsForCache() {
        Task {
            do {
                /// To freshen the cache
                _ = try await self.send(request: .all)
            } catch {
                logger.report("Couldn't automatically freshen faqs cache", error: error)
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
