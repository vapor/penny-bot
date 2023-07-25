import Models
import Logging

struct CachesStorage: Sendable, Codable {

    var reactionCacheData: ReactionCache.Storage?
    var proposalsCheckerData: ProposalsChecker.Storage?

    init() { }

    static func makeFromCachedData(proposalsChecker: ProposalsChecker) async -> CachesStorage {
        var storage = CachesStorage()
        storage.reactionCacheData = await ReactionCache.shared.getCachedDataForCachesStorage()
        storage.proposalsCheckerData = await proposalsChecker.getCachedDataForCachesStorage()
        return storage
    }

    func populateServicesAndReport(proposalsChecker: ProposalsChecker) async {
        if let reactionCacheData = self.reactionCacheData {
            await ReactionCache.shared.consumeCachesStorageData(reactionCacheData)
        }
        if let proposalsCheckerData = proposalsCheckerData {
            await proposalsChecker.consumeCachesStorageData(proposalsCheckerData)
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
