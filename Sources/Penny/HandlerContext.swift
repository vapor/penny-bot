
struct HandlerContext: Sendable {

    struct Services: Sendable {
        let usersService: any UsersService
        let pingsService: any AutoPingsService
        let faqsService: any FaqsService
        let proposalsService: any ProposalsService
        let cachesService: any CachesService
        let discordService: DiscordService
    }

    let services: Services
}
