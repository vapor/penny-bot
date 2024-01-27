@testable import Penny

package struct FakeCachesService: CachesService {
    let context: CachesStorage.Context

    package init(context: CachesStorage.Context) {
        self.context = context
    }

    package func getCachedInfoFromRepositoryAndPopulateServices() async {
        var storage = CachesStorage()
        storage.evolutionCheckerData = .init(
            previousProposals: TestData.proposals,
            queuedProposals: []
        )
        await storage.populateServicesAndReport(context: context)
    }

    package func gatherCachedInfoAndSaveToRepository() async { }
}
