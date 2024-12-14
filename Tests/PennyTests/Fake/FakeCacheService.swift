@testable import Penny

struct FakeCachesService: CachesService {
    let context: CachesStorage.Context

    init(context: CachesStorage.Context) {
        self.context = context
    }

    func getCachedInfoFromRepositoryAndPopulateServices() async {
        var storage = CachesStorage()
        storage.evolutionCheckerData = .init(
            previousProposals: TestData.proposals,
            queuedProposals: []
        )
        storage.swiftReleasesData = .init(
            currentReleases: TestData.swiftReleases
        )
        await storage.populateServicesAndReport(context: context)
    }

    func gatherCachedInfoAndSaveToRepository() async {}
}
