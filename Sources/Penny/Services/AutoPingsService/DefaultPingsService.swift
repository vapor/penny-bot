import DiscordBM
import Logging
import Models
import Shared

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

actor DefaultPingsService: AutoPingsService {

    typealias Expression = S3AutoPingItems.Expression

    let invoker: LambdaInvoker
    var logger = Logger(label: "DefaultPingsService")

    /// Use `getAll()` to retrieve.
    var _cachedItems: S3AutoPingItems?
    /// `[ExpressionHash: Expression]`
    var _cachedExpressionsHashTable: [Int: Expression]?
    var resetItemsTask: Task<(), Never>?

    init(invoker: LambdaInvoker, backgroundProcessor: BackgroundProcessor) {
        self.invoker = invoker
        backgroundProcessor.process {
            await self.getFreshItemsForCache()
        }
        backgroundProcessor.process {
            await self.setUpResetItemsTask()
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
        try await self.send(.insert(.init(discordID: id, expressions: expressions)))
    }

    func remove(
        _ expressions: [Expression],
        forDiscordID id: UserSnowflake
    ) async throws {
        try await self.send(.remove(.init(discordID: id, expressions: expressions)))
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
            return try await self.send(.all)
        }
    }

    func getAllExpressionsHashTable() async throws -> [Int: Expression] {
        if let cachedItems = _cachedExpressionsHashTable {
            return cachedItems
        } else {
            try await self.send(.all)
            return _cachedExpressionsHashTable ?? [:]
        }
    }

    @discardableResult
    func send(_ request: AutoPingsLambdaRequest) async throws -> S3AutoPingItems {
        let items = try await self.invoker.invokeAutoPingsLambda(request)
        freshenCache(items)
        resetItemsTask?.cancel()
        return items
    }

    private func freshenCache(_ new: S3AutoPingItems) {
        logger.trace(
            "Will refresh auto-pings cache",
            metadata: [
                "new": .stringConvertible(new.items)
            ]
        )
        self._cachedItems = new
        self._cachedExpressionsHashTable = Dictionary(
            uniqueKeysWithValues: new.items.map({ ($0.key.hashValue, $0.key) })
        )
        self.resetItemsTask?.cancel()
    }

    private func getFreshItemsForCache() async {
        do {
            /// To freshen the cache
            _ = try await self.send(.all)
        } catch {
            logger.report("Couldn't automatically freshen auto-pings cache", error: error)
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
}
