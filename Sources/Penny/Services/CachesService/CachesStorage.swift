import Logging
import Models

struct CachesStorage: Sendable, Codable {

    struct Context {
        let autoFaqsService: any AutoFaqsService
        let evolutionChecker: EvolutionChecker
        let soChecker: SOChecker
        let swiftReleasesChecker: SwiftReleasesChecker
        let reactionCache: ReactionCache
    }

    var reactionCacheData: ReactionCache.Storage?
    var evolutionCheckerData: EvolutionChecker.Storage?
    var soCheckerData: SOChecker.Storage?
    var swiftReleasesData: SwiftReleasesChecker.Storage?
    var autoFaqsResponseRateLimiter: DefaultAutoFaqsService.ResponseRateLimiter?

    init() {}

    static func makeFromCachedData(context: Context) async -> CachesStorage {
        var storage = CachesStorage()
        storage.reactionCacheData = await context.reactionCache.getCachedDataForCachesStorage()
        storage.evolutionCheckerData = await context.evolutionChecker.getCachedDataForCachesStorage()
        storage.soCheckerData = await context.soChecker.getCachedDataForCachesStorage()
        storage.swiftReleasesData = await context.swiftReleasesChecker.getCachedDataForCachesStorage()
        storage.autoFaqsResponseRateLimiter = await context.autoFaqsService.getCachedDataForCachesStorage()
        return storage
    }

    func populateServicesAndReport(context: Context) async {
        if let reactionCacheData {
            await context.reactionCache.consumeCachesStorageData(reactionCacheData)
        }
        if let evolutionCheckerData {
            await context.evolutionChecker.consumeCachesStorageData(evolutionCheckerData)
        }
        if let soCheckerData {
            await context.soChecker.consumeCachesStorageData(soCheckerData)
        }
        if let swiftReleasesData {
            await context.swiftReleasesChecker.consumeCachesStorageData(swiftReleasesData)
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
        let evolutionCheckerDataCounts =
            evolutionCheckerData.map { data in
                [
                    data.previousProposals.count,
                    data.queuedProposals.count,
                ]
            } ?? []
        let autoFaqsResponseRateLimiterCounts = [autoFaqsResponseRateLimiter?.count ?? 0]

        Logger(label: "CachesStorage").notice(
            "Recovered the cached stuff",
            metadata: [
                "reactionCache_counts": .stringConvertible(reactionCacheDataCounts),
                "evolutionChecker_counts": .stringConvertible(evolutionCheckerDataCounts),
                "soChecker_isNotNil": .stringConvertible(soCheckerData != nil),
                "releasesChecker_isNotEmpty": .stringConvertible(swiftReleasesData?.currentReleases.isEmpty == false),
                "autoFaqsLimiter_counts": .stringConvertible(autoFaqsResponseRateLimiterCounts),
            ]
        )
    }
}
