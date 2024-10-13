import Rendering
import Shared
import ServiceLifecycle

final class HandlerContext: Sendable {
    /// Contain references to this class so need to be initialized separately
    nonisolated(unsafe) var botStateManager: BotStateManager!
    nonisolated(unsafe) var discordEventListener: DiscordEventListener!

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

    init(
        usersService: any UsersService,
        pingsService: any AutoPingsService,
        faqsService: any FaqsService,
        autoFaqsService: any AutoFaqsService,
        cachesService: any CachesService,
        discordService: DiscordService,
        renderClient: RenderClient,
        evolutionChecker: EvolutionChecker,
        soChecker: SOChecker,
        swiftReleasesChecker: SwiftReleasesChecker,
        reactionCache: ReactionCache
    ) {
        self.usersService = usersService
        self.pingsService = pingsService
        self.faqsService = faqsService
        self.autoFaqsService = autoFaqsService
        self.cachesService = cachesService
        self.discordService = discordService
        self.renderClient = renderClient
        self.evolutionChecker = evolutionChecker
        self.soChecker = soChecker
        self.swiftReleasesChecker = swiftReleasesChecker
        self.reactionCache = reactionCache
    }
}
