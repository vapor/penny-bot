import Models
import Logging

struct CachesStorage: Sendable, Codable {

    var reactionCacheData: ReactionCache.Storage?
    var proposalsCheckerData: ProposalsChecker.Storage?

    init() { }

    static func makeFromCachedData(workers: HandlerContext.Workers) async -> CachesStorage {
        var storage = CachesStorage()
        storage.reactionCacheData = await workers.reactionCache.getCachedDataForCachesStorage()
        storage.proposalsCheckerData = await workers.proposalsChecker.getCachedDataForCachesStorage()
        return storage
    }

    func populateServicesAndReport(workers: HandlerContext.Workers) async {
        if let reactionCacheData = self.reactionCacheData {
            await workers.reactionCache.consumeCachesStorageData(reactionCacheData)
        }
        if let proposalsCheckerData = proposalsCheckerData {
            await workers.proposalsChecker.consumeCachesStorageData(proposalsCheckerData)
        }

        let reactionCacheDataCounts = reactionCacheData.map { data in
            [data.givenCoins.count,
             data.normalThanksMessages.count,
             data.forcedInThanksChannelMessages.count]
        } ?? []
        let proposalsCheckerDataCounts = proposalsCheckerData.map { data in
            [data.previousProposals.count,
             data.queuedProposals.count]
        } ?? []

        Logger(label: "CachesStorage").notice("Recovered the cached stuff", metadata: [
            "reactionCache_counts": .stringConvertible(reactionCacheDataCounts),
            "proposalsChecker_counts": .stringConvertible(proposalsCheckerDataCounts),
        ])
    }
}
