
protocol CachesService: Sendable {
    func getCachedInfoFromRepositoryAndPopulateServices(workers: HandlerContext.Workers) async
    func gatherCachedInfoAndSaveToRepository(workers: HandlerContext.Workers) async
}
