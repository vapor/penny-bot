import DiscordBM
import Foundation
import Logging
import NIOPosix
import NIOCore
import AsyncHTTPClient
import Backtrace

@main
struct Penny {
    
    static func main() {
        Backtrace.install()
        
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let client = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
        
        defer {
            try! client.syncShutdown()
            try! eventLoopGroup.syncShutdownGracefully()
        }
        
        bootstrapLoggingSystem(httpClient: client)
        
        let logger = Logger(label: "Penny")
        
        let bot = BotFactory.makeBot(eventLoopGroup, client)
        
        Task {
            await DiscordService.shared.initialize(discordClient: bot.client, logger: logger)
            await DefaultPingsService.shared.initialize(httpClient: client, logger: logger)
            await BotStateManager.shared.initialize(logger: logger)
            
            await bot.addEventHandler { event in
                EventHandler(
                    event: event,
                    coinService: ServiceFactory.makeCoinService(client, logger),
                    logger: logger
                ).handle()
            }
            
            await bot.connect()
            
            await SlashCommandHandler(logger: logger).registerCommands()
        }
        
        RunLoop.current.run()
    }
    
    static func bootstrapLoggingSystem(httpClient: HTTPClient) {
#if DEBUG
        // Discord-logging is disabled in debug, so we can just use a fake url.
        let webhookUrl = "https://discord.com/api/webhooks/1066284436045439037/dSs4nFhjpxcOh6HWD_"
#else
        guard let webhookUrl = Constants.loggingWebhookUrl else {
            fatalError("Missing 'LOGGING_WEBHOOK_URL' env var")
        }
#endif
        guard let token = Constants.botToken else {
            fatalError("Missing 'BOT_TOKEN' env var")
        }
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: DefaultDiscordClient(
                httpClient: httpClient,
                token: token,
                appId: nil
            ),
            configuration: .init(
                fallbackLogger: Logger(
                    label: "DiscordBMFallback",
                    factory: StreamLogHandler.standardOutput(label:metadataProvider:)
                ),
                aliveNotice: .init(
                    address: try! .webhook(.url(webhookUrl)),
                    interval: .hours(12),
                    message: "I'm Alive! :)",
                    initialNoticeMention: .user(Constants.botDevUserId)
                ),
                mentions: [
                    .warning: .user(Constants.botDevUserId),
                    .error: .user(Constants.botDevUserId),
                    .critical: .user(Constants.botDevUserId)
                ],
                extraMetadata: [.warning, .error, .critical],
                disabledLogLevels: [.debug, .trace]
            )
        )
        LoggingSystem.bootstrapWithDiscordLogger(
            address: try! .webhook(.url(webhookUrl)),
            level: .trace,
            makeMainLogHandler: StreamLogHandler.standardOutput(label:metadataProvider:)
        )
    }
}
