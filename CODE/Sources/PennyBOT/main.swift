import Swiftcord
import Foundation
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
app.routes.get { _ in
    return "Ok"
}

DispatchQueue.global().async {
    app.logger.info("Running Vapor Application")
    try? app.run()
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

bot.connect()
