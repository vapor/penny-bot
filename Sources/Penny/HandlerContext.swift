import Rendering
import Shared

struct HandlerContext: Sendable {

    struct Services: Sendable {
        let usersService: any UsersService
        let pingsService: any AutoPingsService
        let faqsService: any FaqsService
        let autoFaqsService: any AutoFaqsService
        let cachesService: any CachesService
        let discordService: DiscordService
        let renderClient: RenderClient
        let evolutionChecker: EvolutionChecker
        let soChecker: SOChecker
        let swiftReleasesChecker: SwiftReleasesChecker
        let reactionCache: ReactionCache
    }

    let services: Services
    let botStateManager: BotStateManager
}
