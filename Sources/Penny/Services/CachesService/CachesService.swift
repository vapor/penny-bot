
protocol CachesService: Sendable {
    func getCachedInfoFromRepositoryAndPopulateServices(proposalsChecker: ProposalsChecker) async
    func gatherCachedInfoAndSaveToRepository(proposalsChecker: ProposalsChecker) async
}
