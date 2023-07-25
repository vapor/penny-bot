@testable import Penny

public struct FakeCachesService: CachesService {
    let workers: HandlerContext.Workers

    public init(workers: HandlerContext.Workers) {
        self.workers = workers
    }

    public func getCachedInfoFromRepositoryAndPopulateServices() async {
        var storage = CachesStorage()
        storage.proposalsCheckerData = .init(
            previousProposals: TestData.proposals,
            queuedProposals: []
        )
        await storage.populateServicesAndReport(workers: workers)
    }

    public func gatherCachedInfoAndSaveToRepository() async { }
}
