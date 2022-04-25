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

        app.routes.get { _ in
            return "Ok"
        }

        let options = ShieldOptions(willBeCaseSensitive: false, willIgnoreBots: true)
        let bot = Shield(token: ProcessInfo.processInfo.environment["BOT_TOKEN"] ?? "", shieldOptions: options)

        // Set activity
        let activity = Activities(name: "Working on myself", type: .playing)
        bot.editStatus(status: .online, activity: activity)

        // Set intents
        bot.setIntents(intents: .guildMessages)

        bot.on(.messageCreate) { data in
            let msg = data as! Message
            
            if msg.content == "++ping" {
                msg.reply(with: "Pong!")
            }
        }

        let messageLogger = MessageLogger(bot: bot)
        messageLogger.messageLogger()

        //let slashCommandListener = SlashCommandListener(bot: bot)
        //slashCommandListener.BuildCommands()
        //slashCommandListener.ListenToSlashCommands()
        
        try await app.run()
        bot.connect()
    }
}
