import Models

struct CacheStorage: Codable {

    struct ProposalsCheckerStorage: Codable {
        var previousProposals: [Proposal]
        var queuedProposals: [QueuedProposal]
    }

    var reactionCacheData: ReactionCache.Storage?
    var proposalsCheckerData: ProposalsCheckerStorage?

    init() { }

    static func makeFromCachedData() async -> CacheStorage {
        var storage = CacheStorage()
        storage.reactionCacheData = await ReactionCache.shared.toCacheStorageData()
        storage.proposalsCheckerData = await ProposalsChecker.shared.toCacheStorageData()
        return storage
    }

    func populateServices() async {
        if let reactionCacheData = self.reactionCacheData {
            await ReactionCache.shared.fromCacheStorageData(reactionCacheData)
        }
        if let proposalsCheckerData = proposalsCheckerData {
            await ProposalsChecker.shared.fromCacheStorageData(proposalsCheckerData)
        }
    }
}
