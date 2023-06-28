import Models
import Logging

struct CachesStorage: Sendable, Codable {

    var reactionCacheData: ReactionCache.Storage?
    var proposalsCheckerData: ProposalsChecker.Storage?

    init() { }

    static func makeFromCachedData() async -> CachesStorage {
        var storage = CachesStorage()
        storage.reactionCacheData = await ReactionCache.shared.getCachedDataForCachesStorage()
        storage.proposalsCheckerData = await ProposalsChecker.shared.getCachedDataForCachesStorage()
        return storage
    }

    func populateServicesAndReport() async {
        if let reactionCacheData = self.reactionCacheData {
            await ReactionCache.shared.consumeCachesStorageData(reactionCacheData)
        }
        if let proposalsCheckerData = proposalsCheckerData {
            await ProposalsChecker.shared.consumeCachesStorageData(proposalsCheckerData)
        }

        let reactionCacheDataCounts = reactionCacheData == nil ? [] : [
            reactionCacheData!.cachedAuthorIds.count,
            reactionCacheData!.givenCoins.count,
            reactionCacheData!.channelWithLastThanksMessage.count,
            reactionCacheData!.thanksChannelForcedMessages.count,
        ]
        let proposalsCheckerDataCounts = proposalsCheckerData == nil ? [] : [
            proposalsCheckerData!.previousProposals.count,
            proposalsCheckerData!.queuedProposals.count,
        ]
        Logger(label: "CachesStorage").notice("Recovered some cached stuff", metadata: [
            "reactionCache_counts": .stringConvertible(reactionCacheDataCounts),
            "proposalsChecker_counts": .stringConvertible(proposalsCheckerDataCounts),
        ])
    }
}