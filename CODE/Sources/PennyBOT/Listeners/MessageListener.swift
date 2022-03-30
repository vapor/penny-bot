import Foundation
import Swiftcord
import PennyModels

class MessageLogger {
    let bot: Swiftcord
    var messageCache = [Snowflake:Message]()
    let coinService: CoinService = CoinService()
    
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
                let sender = "<@!\(msg.author!.id)>"
                let receiver = msg.content.getUser
                
                // A user is not allowed to give themselves coins
                if "<@!\(msg.author!.id)>" == receiver {
                    return
                }
                
                let coinRequest = CoinRequest(
                    amount: 1, //Possible to make this a variable later to include in the thanks message
                    from: sender,
                    receiver: receiver,
                    source: .discord,
                    reason: .userProvided
                )
                
                // Insert api call here
                _ = Task {
                    let response = try await self.coinService.postCoin(with: coinRequest)
                    
                    msg.reply(with: response)
                }
            }
        }
    }
}
