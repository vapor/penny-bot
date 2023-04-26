import DiscordBM
import Foundation
import Logging
import NIOPosix
import NIOCore
import AsyncHTTPClient
@preconcurrency import Lifecycle

@main
struct Penny {

    static func main() async {
        await start().wait()
    }

    /// Tests only need to call this, not `main()`
    @discardableResult
    static func start() async -> ServiceLifecycle {
        let lifecycle = ServiceLifecycle()

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        lifecycle.registerShutdown(
            label: "eventLoopGroup",
            .sync(eventLoopGroup.syncShutdownGracefully)
        )

        let client = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
        lifecycle.registerShutdown(
            label: "httpClient",
            .sync(client.syncShutdown)
        )

        await bootstrapLoggingSystem(httpClient: client)

        let bot = BotFactory.makeBot(eventLoopGroup, client)
        let cache = await BotFactory.makeCache(bot)

        await DiscordService.shared.initialize(discordClient: bot.client, cache: cache)
        await DefaultPingsService.shared.initialize(httpClient: client)
        await CommandsManager().registerCommands()
        await BotStateManager.shared.initialize()

        await bot.addEventHandler { event in
            EventHandler(
                event: event,
                coinService: ServiceFactory.makeCoinService(client)
            ).handle()
        }

        await bot.connect()

        return lifecycle
    }
    
    static func bootstrapLoggingSystem(httpClient: HTTPClient) async {
#if DEBUG
        // Discord-logging is disabled in debug based on the logger configuration,
        // so we can just use a fake url.
        let webhookUrl = "https://discord.com/api/webhooks/1066284436045439037/dSs4nFhjpxcOh6HWD_"
#else
        guard let webhookUrl = Constants.loggingWebhookUrl else {
            fatalError("Missing 'LOGGING_WEBHOOK_URL' env var")
        }
#endif
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            httpClient: httpClient,
            configuration: .init(
                aliveNotice: .init(
                    address: try! .url(webhookUrl),
                    interval: nil,
                    message: "I'm Alive! :)",
                    initialNoticeMention: .user(Constants.botDevUserId)
                ),
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
            address: try! .url(webhookUrl),
            level: .trace,
            makeMainLogHandler: StreamLogHandler.standardOutput(label:metadataProvider:)
        )
    }
}
