import DiscordBM
import DiscordLogger
import AsyncHTTPClient
import NIOCore
import SotoCore
import Shared
import Logging
import ServiceLifecycle
import NIOPosix

struct PennyService: MainService {
    func bootstrapLoggingSystem(httpClient: HTTPClient) async throws {
#if DEBUG
        // Discord-logging is disabled in debug based on the logger configuration,
        // so we can just use an invalid url
        let webhookURL = "https://discord.com/api/webhooks/1066284436045439037/dSs4nFhjpxcOh6HWD_"
#else
        let webhookURL = Constants.loggingWebhookURL
#endif
        DiscordGlobalConfiguration.logManager = await DiscordLogManager(
            httpClient: httpClient,
            configuration: .init(
                aliveNotice: .init(
                    address: try! .url(webhookURL),
                    interval: nil,
                    message: "I'm Alive! :)",
                    initialNoticeMention: .user(Constants.botDevUserId)
                ),
                sendFullLogsAsAttachment: .enabled,
                mentions: [
                    .warning: .user(Constants.botDevUserId),
                    .error: .user(Constants.botDevUserId),
                    .critical: .user(Constants.botDevUserId)
                ],
                extraMetadata: [.warning, .error, .critical],
                disabledLogLevels: [.debug, .trace],
                disabledInDebug: true
            )
        )
        await LoggingSystem.bootstrapWithDiscordLogger(
            address: try! .url(webhookURL),
            level: .trace,
            makeMainLogHandler: { label, metadataProvider in
                StreamLogHandler.standardOutput(
                    label: label,
                    metadataProvider: metadataProvider
                )
            }
        )
    }

    func makeBot(httpClient: HTTPClient) async throws -> any GatewayManager {
        /// Custom caching for the `getApplicationGlobalCommands` endpoint.
        let clientConfiguration = ClientConfiguration(
            cachingBehavior: .custom(
                apiEndpoints: [
                    .listApplicationCommands: .seconds(60 * 60) /// 1 hour
                ],
                apiEndpointsDefaultTTL: .seconds(5)
            )
        )
        return await BotGatewayManager(
            eventLoopGroup: MultiThreadedEventLoopGroup.singleton,
            httpClient: httpClient,
            clientConfiguration: clientConfiguration,
            token: Constants.botToken,
            presence: .init(
                activities: [.init(name: "you", type: .game)],
                status: .online,
                afk: false
            ),
            intents: [
                .guilds,
                .guildMembers,
                .guildMessages,
                .messageContent,
                .guildMessageReactions,
                .guildModeration
            ]
        )
    }

    func makeCache(bot: any GatewayManager) async throws -> DiscordCache {
        await DiscordCache(
            gatewayManager: bot,
            intents: [.guilds, .guildMembers, .messageContent, .guildMessages],
            requestAllMembers: .enabled,
            messageCachingPolicy: .saveEditHistoryAndDeleted
        )
    }

    func beforeConnectCall(
        bot: any GatewayManager,
        cache: DiscordCache,
        httpClient: HTTPClient,
        awsClient: AWSClient
    ) async throws -> HandlerContext {
        let backgroundRunner = BackgroundRunner()
        let usersService = ServiceFactory.makeUsersService(
            httpClient: httpClient,
            apiBaseURL: Constants.apiBaseURL
        )
        let pingsService = DefaultPingsService(
            httpClient: httpClient,
            backgroundRunner: backgroundRunner
        )
        let faqsService = DefaultFaqsService(
            httpClient: httpClient,
            backgroundRunner: backgroundRunner
        )
        let autoFaqsService = DefaultAutoFaqsService(
            httpClient: httpClient,
            backgroundRunner: backgroundRunner
        )
        let evolutionService = DefaultEvolutionService(httpClient: httpClient)
        let soService = DefaultSOService(httpClient: httpClient)
        let swiftReleasesService = DefaultSwiftReleasesService(httpClient: httpClient)
        let discordService = DiscordService(
            discordClient: bot.client,
            cache: cache,
            backgroundRunner: backgroundRunner
        )
        let evolutionChecker = EvolutionChecker(
            evolutionService: evolutionService,
            discordService: discordService
        )
        let soChecker = SOChecker(
            soService: soService,
            discordService: discordService
        )
        let swiftReleasesChecker = SwiftReleasesChecker(
            swiftReleasesService: swiftReleasesService,
            discordService: discordService
        )
        let reactionCache = ReactionCache()
        let cachesService = DefaultCachesService(
            awsClient: awsClient,
            context: .init(
                autoFaqsService: autoFaqsService,
                evolutionChecker: evolutionChecker,
                soChecker: soChecker,
                swiftReleasesChecker: swiftReleasesChecker,
                reactionCache: reactionCache
            )
        )
        
        let context = HandlerContext(
            backgroundRunner: backgroundRunner,
            usersService: usersService,
            pingsService: pingsService,
            faqsService: faqsService,
            autoFaqsService: autoFaqsService,
            cachesService: cachesService,
            discordService: discordService,
            renderClient: .init(
                renderer: try .forPenny(
                    httpClient: httpClient,
                    logger: Logger(label: "Penny+Leaf"),
                    on: httpClient.eventLoopGroup.next()
                )
            ),
            evolutionChecker: evolutionChecker,
            soChecker: soChecker,
            swiftReleasesChecker: swiftReleasesChecker,
            reactionCache: reactionCache
        )
        context.botStateManager = BotStateManager(context: context)
        context.discordEventListener = DiscordEventListener(bot: bot, context: context)

        await CommandsManager(context: context).registerCommands()

        return context
    }

    func runServices(context: HandlerContext) async throws {
        /// Wait 5 seconds to make sure the bot is completely connected to Discord through websocket,
        /// and so it can receive events already.
        /// This is here until when/if DiscordBM gains better support for notifying you
        /// of the first connection.
        /// We could manually handle that here too, but I'd like it to be available in DiscordBM.
        try await Task.sleep(for: .seconds(5))
        /// Initialize `BotStateManager` after `bot.connect()` and `bot.makeEventsStream()`.
        /// since it communicates through Discord and will need the Gateway connection.
        let services = ServiceGroup(
            services: [
                context.backgroundRunner,
                context.botStateManager,
                context.evolutionChecker,
//                context.soChecker,
                context.swiftReleasesChecker,
                context.discordEventListener
            ],
            logger: Logger(label: "ServiceGroup")
        )

        try await services.run()
    }
}
