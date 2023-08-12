@testable import Penny

public struct FakeCachesService: CachesService {
    let context: CachesStorage.Context

    public init(context: CachesStorage.Context) {
        self.context = context
    }

    public func getCachedInfoFromRepositoryAndPopulateServices() async {
        var storage = CachesStorage()
        storage.proposalsCheckerData = .init(
            previousProposals: TestData.proposals,
            queuedProposals: []
        )
        await storage.populateServicesAndReport(context: context)
    }

    public func gatherCachedInfoAndSaveToRepository() async { }
}
