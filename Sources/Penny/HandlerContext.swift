
struct HandlerContext: Sendable {

    struct Services: Sendable {
        let usersService: any UsersService
        let pingsService: any AutoPingsService
        let faqsService: any FaqsService
        let cachesService: any CachesService
        let discordService: DiscordService
        let proposalsChecker: ProposalsChecker
    }

    let services: Services
    let botStateManager: BotStateManager
}
