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
        
        let bot = BotFactory.makeBot(eventLoopGroup, client)
        
        Task {
            let cache = await DiscordCache(
                gatewayManager: bot,
                intents: nil,
                requestAllMembers: nil
            )
            
            await DiscordService.shared.initialize(discordClient: bot.client, cache: cache)
            await DefaultPingsService.shared.initialize(httpClient: client)
            await BotStateManager.shared.initialize()
            
            await bot.addEventHandler { event in
                EventHandler(
                    event: event,
                    coinService: ServiceFactory.makeCoinService(client)
                ).handle()
            }
            
            await bot.connect()
            
            await SlashCommandHandler().registerCommands()
        }
        
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
                disabledLogLevels: [.debug, .trace]
            )
        )
        LoggingSystem.bootstrapWithDiscordLogger(
            address: try! .url(webhookUrl),
            level: .trace,
            makeMainLogHandler: StreamLogHandler.standardOutput(label:metadataProvider:)
        )
    }
}
