import Foundation
import Swiftcord

class MessageLogger {
    let bot: Swiftcord
    var messageCache = [Snowflake:Message]()
    
    init(bot: Swiftcord) {
        self.bot = bot
    }
    
    func messageLogger() {
        // When a message is created
        self.bot.on(.messageCreate) { data in
            let msg = data as! Message
            
            if msg.channel.id != 441327731486097429 {
                return
            }
            
            print("Sent from \(msg.channel.id)")
        }
    }
}
