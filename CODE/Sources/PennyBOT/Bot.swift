import Swiftcord
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

        let options = SwiftcordOptions(isBot: true, willLog: true)
        let bot = Swiftcord(token: ProcessInfo.processInfo.environment["BOT_TOKEN"] ?? "", options: options, logger: logger, eventLoopGroup: eventLoopGroup)

        
        // Set activity
        let activity = Activities(name: "Showing appreciation to the amazing Vapor community", type: .playing)
        bot.editStatus(status: .online, activity: activity)

        // Set intents
        bot.setIntents(intents: .guildMessages)

        bot.addListeners(MessageLogger(logger: logger, httpClient: client))
        //let messageLogger = MessageLogger(bot: bot)
        //messageLogger.messageLogger()

        //let slashCommandListener = SlashCommandListener(bot: bot)
        //slashCommandListener.BuildCommands()
        //slashCommandListener.ListenToSlashCommands()
        
        bot.connect()
    }
}
