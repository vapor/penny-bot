import AsyncHTTPClient
import Collections
import DiscordModels
/// Import full foundation even on linux for `hash`, for now.
import Foundation
import Logging
import Models
import NIOCore
import NIOFoundationCompat
import NIOHTTP1
import Shared

actor DefaultAutoFaqsService: AutoFaqsService {

    struct ResponseRateLimiter: Sendable, Codable {

        struct ID: Sendable, Codable, Hashable {
            let receiverID: UserSnowflake
            let faqHash: Int
        }

        private var expirationTimeTable: OrderedDictionary<ID, Date> = [:]
        private var expirationTime: TimeInterval {
            60 * 60 * 6
        }
        var count: Int {
            self.expirationTimeTable.count
        }

        /// Returns "can respond?" and assumes that the response will always be sent.
        mutating func canRespond(to id: ID) -> Bool {
            defer {
                /// Cleanup old items.
                self.expirationTimeTable.removeAll { _, value in value < Date() }
            }

            /// See if "can respond".
            if let existing = self.expirationTimeTable[id] {
                if existing < Date() {
                    self.expirationTimeTable[id] = Date().addingTimeInterval(expirationTime)
                    return true
                } else {
                    return false
                }
            } else {
                self.expirationTimeTable[id] = Date().addingTimeInterval(expirationTime)
                return true
            }
        }
    }

    var httpClient: HTTPClient!
    var logger = Logger(label: "DefaultAutoFaqsService")

    /// Use `getAll()` to retrieve.
    var _cachedItems: [String: String]?
    /// Use `getAllFolded()` to retrieve.
    var _cachedFoldedItems: [String: String]?
    /// Use `getAllNamesHashTable()` to retrieve.
    /// `[NameHash: Name]`
    var _cachedNamesHashTable: [Int: String]?
    var resetItemsTask: Task<(), Never>?

    /// To not send the same faq-answer to the same person again and again.
    var responseRateLimiter = ResponseRateLimiter()

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    init(httpClient: HTTPClient, backgroundProcessor: BackgroundProcessor) {
        self.httpClient = httpClient
        backgroundProcessor.process {
            await self.getFreshItemsForCache()
        }
        backgroundProcessor.process {
            await self.setUpResetItemsTask()
        }
    }

    func insert(expression: String, value: String) async throws {
        try await self.send(request: .add(expression: expression, value: value))
    }

    func remove(expression: String) async throws {
        try await self.send(request: .remove(expression: expression))
    }

    func get(expression: String) async throws -> String? {
        try await self.getAll()[expression]
    }

    func getName(hash: Int) async throws -> String? {
        try await self.getAllNamesHashTable()[hash]
    }

    func getAll() async throws -> [String: String] {
        if let _cachedItems {
            return _cachedItems
        } else {
            try await self.send(request: .all)
            return _cachedItems ?? [:]
        }
    }

    func getAllFolded() async throws -> [String: String] {
        if let _cachedFoldedItems {
            return _cachedFoldedItems
        } else {
            try await self.send(request: .all)
            return _cachedFoldedItems ?? [:]
        }
    }

    func getAllNamesHashTable() async throws -> [Int: String] {
        if let _cachedNamesHashTable {
            return _cachedNamesHashTable
        } else {
            try await self.send(request: .all)
            return _cachedNamesHashTable ?? [:]
        }
    }

    /// Must "freshenCache" if it didn't throw an error.
    func send(request autoFaqsRequest: AutoFaqsRequest) async throws {
        let url = Constants.apiBaseURL + "/auto-faqs"
        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try encoder.encode(autoFaqsRequest)
        request.body = .bytes(data)
        let response = try await httpClient.execute(
            request,
            timeout: .seconds(60),
            logger: self.logger
        )
        logger.trace("HTTP head", metadata: ["response": "\(response)"])

        guard 200..<300 ~= response.status.code else {
            let collected = try? await response.body.collect(upTo: 1 << 16)
            /// 64 KiB
            let body = collected.map { String(buffer: $0) } ?? "nil"
            logger.error(
                "Faqs-service failed",
                metadata: [
                    "status": "\(response.status)",
                    "headers": "\(response.headers)",
                    "body": "\(body)",
                ]
            )
            throw ServiceError.badStatus(response.status)
        }

        let body = try await response.body.collect(upTo: 1 << 24)
        /// 16 MiB
        let items = try decoder.decode([String: String].self, from: body)
        freshenCache(items)
        resetItemsTask?.cancel()
    }

    private func freshenCache(_ new: [String: String]) {
        logger.trace(
            "Will refresh auto-faqs cache",
            metadata: [
                "new": .stringConvertible(new)
            ]
        )
        self._cachedItems = new
        self._cachedFoldedItems = Dictionary(
            new.map({ ($0.key.superHeavyFolded(), $0.value) }),
            uniquingKeysWith: { l, _ in l }
        )
        self._cachedNamesHashTable = Dictionary(
            uniqueKeysWithValues: new.map({ ($0.key.hash, $0.key) })
        )
        self.resetItemsTask?.cancel()
    }

    private func getFreshItemsForCache() async {
        do {
            /// To freshen the cache
            _ = try await self.send(request: .all)
        } catch {
            logger.report("Couldn't automatically freshen auto-faqs cache", error: error)
        }
    }

    private func setUpResetItemsTask() async {
        self.resetItemsTask?.cancel()
        let task = Task<Void, Never> {
            /// Force-refresh cache after 6 hours of no activity
            if (try? await Task.sleep(for: .seconds(60 * 60 * 6))) != nil {
                self._cachedItems = nil
                await self.getFreshItemsForCache()
                await self.setUpResetItemsTask()
            } else {
                /// If canceled, set up the task again.
                /// This way, the functions above can cancel this when they've got fresh items
                /// and this will just reschedule itself for a later time.
                await self.setUpResetItemsTask()
            }
        }
        self.resetItemsTask = task
        await task.value
    }

    func canRespond(receiverID: UserSnowflake, faqHash: Int) -> Bool {
        self.responseRateLimiter.canRespond(
            to: .init(
                receiverID: receiverID,
                faqHash: faqHash
            )
        )
    }

    func consumeCachesStorageData(_ storage: ResponseRateLimiter) {
        self.responseRateLimiter = storage
    }

    func getCachedDataForCachesStorage() -> ResponseRateLimiter {
        self.responseRateLimiter
    }
}
