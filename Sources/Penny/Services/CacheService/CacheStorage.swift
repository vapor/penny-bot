import Models

struct CachesStorage: Codable {

    struct ProposalsCheckerStorage: Codable {
        var previousProposals: [Proposal]
        var queuedProposals: [QueuedProposal]
    }

    var reactionCacheData: ReactionCache.Storage?
    var proposalsCheckerData: ProposalsCheckerStorage?

    init() { }

    static func makeFromCachedData() async -> CachesStorage {
        var storage = CachesStorage()
        storage.reactionCacheData = await ReactionCache.shared.toCachesStorageData()
        storage.proposalsCheckerData = await ProposalsChecker.shared.toCachesStorageData()
        return storage
    }

    func populateServices() async {
        if let reactionCacheData = self.reactionCacheData {
            await ReactionCache.shared.fromCachesStorageData(reactionCacheData)
        }
        if let proposalsCheckerData = proposalsCheckerData {
            await ProposalsChecker.shared.fromCachesStorageData(proposalsCheckerData)
        }
    }
}
