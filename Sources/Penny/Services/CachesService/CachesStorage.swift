import Logging
import Models

struct CachesStorage: Sendable, Codable {

    struct Context {
        let autoFaqsService: any AutoFaqsService
        let proposalsChecker: ProposalsChecker
        let reactionCache: ReactionCache
    }

    var reactionCacheData: ReactionCache.Storage?
    var proposalsCheckerData: ProposalsChecker.Storage?
    var autoFaqsResponseRateLimiter: DefaultAutoFaqsService.ResponseRateLimiter?

    init() {}

    static func makeFromCachedData(context: Context) async -> CachesStorage {
        var storage = CachesStorage()
        storage.reactionCacheData = await context.reactionCache.getCachedDataForCachesStorage()
        storage.proposalsCheckerData = await context.proposalsChecker
            .getCachedDataForCachesStorage()
        storage.autoFaqsResponseRateLimiter = await context.autoFaqsService
            .getCachedDataForCachesStorage()
        return storage
    }

    func populateServicesAndReport(context: Context) async {
        if let reactionCacheData {
            await context.reactionCache.consumeCachesStorageData(reactionCacheData)
        }
        if let proposalsCheckerData {
            await context.proposalsChecker.consumeCachesStorageData(proposalsCheckerData)
        }
        if let autoFaqsResponseRateLimiter {
            await context.autoFaqsService.consumeCachesStorageData(autoFaqsResponseRateLimiter)
        }

        let reactionCacheDataCounts =
            reactionCacheData.map { data in
                [
                    data.givenCoins.count,
                    data.normalThanksMessages.count,
                    data.forcedInThanksChannelMessages.count,
                ]
            } ?? []
        let proposalsCheckerDataCounts =
            proposalsCheckerData.map { data in
                [
                    data.previousProposals.count,
                    data.queuedProposals.count,
                ]
            } ?? []
        let autoFaqsResponseRateLimiterCounts = [autoFaqsResponseRateLimiter?.count ?? 0]

        Logger(label: "CachesStorage")
            .notice(
                "Recovered the cached stuff",
                metadata: [
                    "reactionCache_counts": .stringConvertible(reactionCacheDataCounts),
                    "proposalsChecker_counts": .stringConvertible(proposalsCheckerDataCounts),
                    "autoFaqsRateLimiter_counts": .stringConvertible(
                        autoFaqsResponseRateLimiterCounts
                    ),
                ]
            )
    }
}
