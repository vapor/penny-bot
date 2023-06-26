import Models

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

    func populateServices() async {
        if let reactionCacheData = self.reactionCacheData {
            await ReactionCache.shared.consumeCachesStorageData(reactionCacheData)
        }
        if let proposalsCheckerData = proposalsCheckerData {
            await ProposalsChecker.shared.consumeCachesStorageData(proposalsCheckerData)
        }
    }
}
