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
        guard let webhookUrl = Constants.loggingWebhookUrl,
              let token = Constants.botToken,
              let appId = Constants.botId
        else {
            fatalError("Missing 'LOGGING_WEBHOOK_URL' or 'BOT_TOKEN' or 'BOT_APP_ID' env vars")
        }
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: DefaultDiscordClient(
                httpClient: httpClient,
                token: token,
                appId: appId
            ),
            configuration: .init(
                fallbackLogger: Logger(
                    label: "DiscordBMFallback",
                    factory: StreamLogHandler.standardOutput(label:metadataProvider:)
                ),
                aliveNotice: .init(
                    address: try! .webhook(.url(webhookUrl)),
                    interval: .hours(3),
                    message: "I'm Alive! :)",
                    initialNoticeMention: .user(Constants.botDevUserId)
                ),
                mentions: [
                    .warning: .user(Constants.botDevUserId),
                    .error: .user(Constants.botDevUserId)
                ],
                extraMetadata: [.warning, .error],
                disabledLogLevels: [.debug, .trace]
            )
        )
        LoggingSystem.bootstrapWithDiscordLogger(
            address: try! .webhook(.url(webhookUrl)),
            level: .trace,
            makeStdoutLogHandler: StreamLogHandler.standardOutput(label:metadataProvider:)
        )
    }
}
