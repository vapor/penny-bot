import AsyncHTTPClient
import DiscordBM
import DiscordLogger
import Logging
import NIOCore
import NIOPosix
import Rendering
import ServiceLifecycle
import Shared
import SotoCore

struct PennyService: MainService {
    func bootstrapLoggingSystem(httpClient: HTTPClient) async throws {
        // Discord-logging is disabled in debug based on the logger configuration,
        // so we can just use an invalid url
        let webhookURL =
            Constants.deploymentEnvironment == .prod
            ? Constants.loggingWebhookURL : "https://discord.com/api/webhooks/1066284436045439037/dSs4nFhjpxcOh6HWD_"

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
                    .critical: .user(Constants.botDevUserId),
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
                    .listApplicationCommands: .seconds(60 * 60)/// 1 hour
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
                .guildModeration,
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
        let backgroundProcessor = BackgroundProcessor()
        let usersService = ServiceFactory.makeUsersService(
            httpClient: httpClient,
            apiBaseURL: Constants.apiBaseURL
        )
        let pingsService = DefaultPingsService(
            httpClient: httpClient,
            backgroundProcessor: backgroundProcessor
        )
        let faqsService = DefaultFaqsService(
            httpClient: httpClient,
            backgroundProcessor: backgroundProcessor
        )
        let autoFaqsService = DefaultAutoFaqsService(
            httpClient: httpClient,
            backgroundProcessor: backgroundProcessor
        )
        let evolutionService = DefaultEvolutionService(httpClient: httpClient)
        let soService = DefaultSOService(httpClient: httpClient)
        let swiftReleasesService = DefaultSwiftReleasesService(httpClient: httpClient)
        let discordService = DiscordService(
            discordClient: bot.client,
            cache: cache,
            backgroundProcessor: backgroundProcessor
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
            backgroundProcessor: backgroundProcessor,
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
        /// Services that need to wait for bot connection
        let botStateManagerWrappedService = WaiterService(
            underlyingService: context.botStateManager,
            processingOn: context.backgroundProcessor,
            passingContinuationWith: {
                await context.discordEventListener.addConnectionWaiterContinuation($0)
            }
        )

        /// Services that need to wait for caches population
        let evolutionCheckerWrappedService = WaiterService(
            underlyingService: context.evolutionChecker,
            processingOn: context.backgroundProcessor,
            passingContinuationWith: {
                await context.botStateManager.addCachesPopulationContinuation($0)
            }
        )
        let soCheckerWrappedService = WaiterService(
            underlyingService: context.soChecker,
            processingOn: context.backgroundProcessor,
            passingContinuationWith: {
                await context.botStateManager.addCachesPopulationContinuation($0)
            }
        )
        let swiftReleasesCheckerWrappedService = WaiterService(
            underlyingService: context.swiftReleasesChecker,
            processingOn: context.backgroundProcessor,
            passingContinuationWith: {
                await context.botStateManager.addCachesPopulationContinuation($0)
            }
        )

        let services = ServiceGroup(
            services: [
                context.backgroundProcessor,
                context.discordEventListener,
                botStateManagerWrappedService,
                evolutionCheckerWrappedService,
                soCheckerWrappedService,
                swiftReleasesCheckerWrappedService,
            ],
            logger: Logger(label: "ServiceGroup")
        )

        try await services.run()
    }
}
