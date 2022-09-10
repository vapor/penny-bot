import DiscordBM
import Foundation
import Logging
import NIOPosix
import NIOCore
import AsyncHTTPClient
import Backtrace

@main
struct Penny {
    static func main() async throws {
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
        
        let bot = GatewayManager(
            eventLoopGroup: eventLoopGroup,
            httpClient: client,
            token: ProcessInfo.processInfo.environment["BOT_TOKEN"] ?? "",
            appId: ProcessInfo.processInfo.environment["BOT_APP_ID"] ?? "",
            presence: .init(
                activities: [
                    .init(name: "Showing appreciation to the amazing Vapor community", type: .game)
                ],
                status: .online,
                afk: false
            ),
            intents: [.guildMessages, .messageContent]
        )
        
        await bot.addEventHandler { event in
            EventHandler(
                event: event,
                discordClient: bot.client,
                coinService: CoinService(logger: logger, httpClient: client),
                logger: logger
            ).handle()
        }
        //let messageLogger = MessageLogger(bot: bot)
        //messageLogger.messageLogger()

        //let slashCommandListener = SlashCommandListener(bot: bot)
        //slashCommandListener.BuildCommands()
        //slashCommandListener.ListenToSlashCommands()
        
        bot.connect()
    }
}
