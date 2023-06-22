import AsyncHTTPClient

enum ServiceFactory {
    static var makeCoinService: () -> any CoinService = {
        DefaultCoinService.shared
    }

    static var makePingsService: () -> any AutoPingsService = {
        DefaultPingsService.shared
    }

    static var makeProposalsService: (HTTPClient) -> any ProposalsService = {
        DefaultProposalsService(httpClient: $0)
    }

    static var makeHelpsService: () -> any HelpsService = {
        DefaultHelpsService.shared
    }

    static var initializeAndRunProposalsChecker: (HTTPClient) async -> Void = {
        await ProposalsChecker.shared.initialize(
            proposalsService: ServiceFactory.makeProposalsService($0)
        )
        ProposalsChecker.shared.run()
    }
}
