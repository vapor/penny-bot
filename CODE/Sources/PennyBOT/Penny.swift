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
            
            await SlashCommandHandler(
                discordClient: bot.client,
                logger: logger
            ).registerCommands()
        }
        
        RunLoop.current.run()
    }
}
