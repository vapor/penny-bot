
protocol CachesService: Sendable {
    func getCachedInfoFromRepositoryAndPopulateServices() async
    func gatherCachedInfoAndSaveToRepository() async
}
