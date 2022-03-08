import Swiftcord

let bot = Swiftcord(token: "Yout bot token here")

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

bot.connect()
