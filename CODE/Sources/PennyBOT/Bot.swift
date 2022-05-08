import Swiftcord
import Foundation
import Vapor

extension Application {
    func run() async throws {
        let appThread = Thread {
            do {
                self.logger.info("Running Vapor Application")
                try self.run()
                exit(0)
            } catch {
                print(error)
                exit(1)
            }
        }

        appThread.name = "Application"
        appThread.start()
    }
}

@main
struct Penny {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = Application(env)
        defer { app.shutdown() }
        
        app.logger.logLevel = .debug

        app.routes.get { _ in
            return "Ok"
        }

        let options = SwiftcordOptions(isBot: true, willLog: true)
        let bot = Swiftcord(token: ProcessInfo.processInfo.environment["BOT_TOKEN"] ?? "", options: options, logger: app.logger, eventLoopGroup: app.eventLoopGroup)

        
        // Set activity
        let activity = Activities(name: "Working on myself", type: .playing)
        bot.editStatus(status: .online, activity: activity)

        // Set intents
        bot.setIntents(intents: .guildMessages)

        bot.addListeners(MessageLogger(logger: app.logger, httpClient: app.http.client.shared))
        //let messageLogger = MessageLogger(bot: bot)
        //messageLogger.messageLogger()

        //let slashCommandListener = SlashCommandListener(bot: bot)
        //slashCommandListener.BuildCommands()
        //slashCommandListener.ListenToSlashCommands()
        
        try await app.run()
        bot.connect()
        
        dispatchMain()
    }
}
