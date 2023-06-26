@testable import Penny

public struct FakeCachesService: CachesService {
    public func getCachedInfoFromRepositoryAndPopulateServices() async {
        var storage = CacheStorage()
        storage.proposalsCheckerData = .init(
            previousProposals: TestData.proposals,
            queuedProposals: []
        )
        await storage.populateServices()
    }

    public func gatherCachedInfoAndSaveToRepository() async { }

    public init() { }
}
