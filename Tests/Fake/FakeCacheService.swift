@testable import Penny

public struct FakeCachesService: CachesService {
    public func getCachedInfoFromRepositoryAndPopulateServices() async {
        var storage = CachesStorage()
        storage.proposalsCheckerData = .init(
            previousProposals: TestData.proposals,
            queuedProposals: []
        )
        await storage.populateServicesAndReport()
    }

    public func gatherCachedInfoAndSaveToRepository() async { }

    public init() { }
}
