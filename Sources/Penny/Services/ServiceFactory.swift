import AsyncHTTPClient

enum ServiceFactory {
    static var makeUsersService: () -> any UsersService = {
        DefaultUsersService.shared
    }

    static var makePingsService: () -> any AutoPingsService = {
        DefaultPingsService.shared
    }

    static var makeProposalsService: (HTTPClient) -> any ProposalsService = {
        DefaultProposalsService(httpClient: $0)
    }

    static var makeFaqsService: () -> any FaqsService = {
        DefaultFaqsService.shared
    }

    static var initiateProposalsChecker: (HTTPClient) async -> Void = {
        await ProposalsChecker.shared.initialize(
            proposalsService: ServiceFactory.makeProposalsService($0)
        )
        ProposalsChecker.shared.run()
    }

    static var makeCachesService: () -> any CachesService = {
        DefaultCachesService.shared
    }
}
