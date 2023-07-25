@testable import Penny

public struct FakeCachesService: CachesService {
    public func getCachedInfoFromRepositoryAndPopulateServices(
        workers: HandlerContext.Workers
    ) async {
        var storage = CachesStorage()
        storage.proposalsCheckerData = .init(
            previousProposals: TestData.proposals,
            queuedProposals: []
        )
        await storage.populateServicesAndReport(workers: workers)
    }

    public func gatherCachedInfoAndSaveToRepository(workers: HandlerContext.Workers) async { }

    public init() { }
}
