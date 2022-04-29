import Foundation
import Swiftcord
import PennyModels

class MessageLogger: ListenerAdapter {
    let coinService: CoinService = CoinService()
    
    override func onMessageCreate(event: Message) async {
        // Stop the bot from responding to other bots and itself
        if event.member?.user?.isBot == true {
            return
        }
        
        // TODO: remove in production
        if event.channel.id != 441327731486097429 {
            return
        }
        
        // Check for coin suffix and if the message contains a user
        if event.content.hasCoinSuffix && event.content.containsUser {
            let sender = "<@\(event.author!.id)>"
            let receiver = event.content.getUser
            
            // A user is not allowed to give themselves coins
            if "<@!\(event.author!.id)>" == receiver || "<@\(event.author!.id)>" == receiver {
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
                
                if response.starts(with: "ERROR-") {
                    event.swiftcord.log("\(response)")
                    _ try await event.reply(with: "Oops. Something went wrong! Please try again later")
                } else {
                    _ = try await event.reply(with: response)
                }
            }
        }
    }
}
