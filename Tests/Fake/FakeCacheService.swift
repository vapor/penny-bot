@testable import Penny

public struct FakeCachesService: CachesService {
    public func getCachedInfoFromRepositoryAndPopulateServices(
        proposalsChecker: ProposalsChecker
    ) async {
        var storage = CachesStorage()
        storage.proposalsCheckerData = .init(
            previousProposals: TestData.proposals,
            queuedProposals: []
        )
        await storage.populateServicesAndReport(proposalsChecker: proposalsChecker)
    }

    public func gatherCachedInfoAndSaveToRepository(proposalsChecker: ProposalsChecker) async { }

    public init() { }
}
