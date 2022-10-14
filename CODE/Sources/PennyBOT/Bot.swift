import DiscordBM
import Foundation
import Logging
import NIOPosix
import NIOCore
import AsyncHTTPClient
import Backtrace

@main
struct Penny {
    
    static var makeBot: (EventLoopGroup, HTTPClient) -> GatewayManager = {
        eventLoopGroup, client in
        guard let token = ProcessInfo.processInfo.environment["BOT_TOKEN"],
              let appId = ProcessInfo.processInfo.environment["BOT_APP_ID"] else {
            fatalError("Missing 'BOT_TOKEN' or 'BOT_APP_ID' env vars")
        }
        return BotGatewayManager(
            eventLoopGroup: eventLoopGroup,
            httpClient: client,
            token: token,
            appId: appId,
            presence: .init(
                activities: [.init(name: "Showing Appreciation", type: .game)],
                status: .online,
                afk: false
            ),
            intents: [.guildMessages, .messageContent, .guildMessageReactions]
        )
    }
    
    static func main() throws {
        Backtrace.install()
//        try LoggingSystem.bootstrap(from: &env)
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        var logger = Logger(label: "Penny")
        logger.logLevel = .trace
        let client = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
        
        defer {
            try! client.syncShutdown()
            try! eventLoopGroup.syncShutdownGracefully()
        }
        
        DiscordGlobalConfiguration.makeLogger = { label in
            var _logger = Logger(label: label)
            _logger.logLevel = logger.logLevel
            return _logger
        }
        
        let bot = makeBot(eventLoopGroup, client)
        
        Task {
            await bot.addEventHandler { event in
                EventHandler(
                    event: event,
                    discordClient: bot.client,
                    coinService: CoinService(logger: logger, httpClient: client),
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
}
