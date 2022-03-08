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
            
            // Stop the bot from responding to other bots and itself
            if msg.member?.user?.isBot == true {
                return
            }
            
            // TODO: remove in production
            if msg.channel.id != 441327731486097429 {
                return
            }
            
            // Check for coin suffix and if the message contains a user
            if msg.content.hasCoinSuffix && msg.content.containsUser {
                let receiver = msg.content.getUser
                
                // A user is not allowed to give themselves coins
                if "<@!\(msg.author!.id)>" == receiver {
                    return
                }
                    
                // Insert api call here
                
                
                // Reply
                msg.reply(with: "\(msg.author?.username ?? "Penny-bot") gave a penny to \(receiver)")
            }
        }
    }
}
