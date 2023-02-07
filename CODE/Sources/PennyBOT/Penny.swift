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
            await BotStateManager.shared.initialize(discordClient: bot.client, logger: logger)
            
            await bot.addEventHandler { event in
                EventHandler(
                    event: event,
                    discordClient: bot.client,
                    coinService: ServiceFactory.makeCoinService(client, logger),
                    logger: logger
                ).handle()
            }
            
            await bot.connect()
        }
        
        SlashCommandHandler(
            discordClient: bot.client,
            logger: logger
        ).registerCommands()
        
        RunLoop.current.run()
    }
    
    static func bootstrapLoggingSystem(httpClient: HTTPClient) {
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
                fallbackLogger: Logger(
                    label: "DiscordBMFallback",
                    factory: StreamLogHandler.standardOutput(label:metadataProvider:)
                ),
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
        LoggingSystem.bootstrapWithDiscordLogger(
            address: try! .url(webhookUrl),
            level: .trace,
            makeMainLogHandler: StreamLogHandler.standardOutput(label:metadataProvider:)
        )
    }
}
