import AsyncHTTPClient

enum ServiceFactory {
    static var initiateProposalsChecker: (HandlerContext) async -> Void = { context in
        await ProposalsChecker.shared.initialize(
            proposalsService: context.services.proposalsService
        )
        ProposalsChecker.shared.run()
    }

    static var initializePingsService: (HTTPClient) async -> Void = { httpClient in
        await DefaultPingsService.shared.initialize(httpClient: httpClient)
    }

    static var initializeFaqsService: (HTTPClient) async -> Void = { httpClient in
        await DefaultFaqsService.shared.initialize(httpClient: httpClient)
    }

    static var makeHandlerContext: (HTTPClient) -> HandlerContext = { httpClient in
        HandlerContext(services: .init(
            usersService: DefaultUsersService.shared,
            pingsService: DefaultPingsService.shared,
            faqsService: DefaultFaqsService.shared,
            proposalsService:  DefaultProposalsService(httpClient: httpClient),
            cachesService: DefaultCachesService.shared,
            discordService: DiscordService.shared
        ))
    }
}
