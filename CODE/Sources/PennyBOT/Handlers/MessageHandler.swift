import DiscordBM
import Logging
import PennyModels

struct MessageHandler {
    
    let discordClient: DiscordClient
    let coinService: CoinService
    let logger: Logger
    let event: Gateway.Message
    
    func handle() async {
        guard let author = event.author else {
            logger.error("Cannot find author of the message. Event: \(event)")
            return
        }
        
        // Stop the bot from responding to other bots and itself
        if author.bot == true {
            return
        }
        
        let sender = "<@\(author.id)>"
        let repliedUser = event.referenced_message?.value.author.map({ "<@\($0.id)>" })
        let coinHandler = CoinHandler(
            text: event.content,
            repliedUser: repliedUser,
            mentionedUsers: event.mentions.map(\.id).map({ "<@\($0)>" }),
            excludedUsers: [sender] // Can't give yourself a coin
        )
        let usersWithNewCoins = coinHandler.findUsers()
        // Return if there are no coins to be granted
        if usersWithNewCoins.isEmpty { return }
        
        var successfulResponses = [String]()
        successfulResponses.reserveCapacity(usersWithNewCoins.count)
        
        for receiver in usersWithNewCoins {
            let coinRequest = CoinRequest(
                // Possible to make this a variable later to include in the thanks message
                amount: 1,
                from: sender,
                receiver: receiver,
                source: .discord,
                reason: .userProvided
            )
            do {
                let response = try await self.coinService.postCoin(with: coinRequest)
                let responseString = "\(response.receiver) now has \(response.coins) coins!"
                successfulResponses.append(responseString)
            } catch {
                logger.error("CoinService failed. Request: \(coinRequest), Error: \(error)")
            }
        }
        
        if successfulResponses.isEmpty {
            // Definitely there were some coin requests that failed.
            await self.respond(with: "Oops. Something went wrong! Please try again later")
        } else {
            // Stitch responses together instead of sending a lot of messages,
            // to consume less Discord rate-limit.
            let finalResponse = successfulResponses.joined(separator: "\n")
            // Discord doesn't like embed-descriptions with more than 4_000 content length.
            if finalResponse.unicodeScalars.count > 4_000 {
                await self.respond(with: "Coins were granted to a lot of members!")
            } else {
                await self.respond(with: finalResponse)
            }
        }
    }
    
    private func respond(with response: String) async {
        do {
            let apiResponse = try await discordClient.createMessage(
                channelId: event.channel_id,
                payload: .init(
                    embeds: [.init(
                        description: response,
                        color: .vaporPurple
                    )],
                    message_reference: .init(
                        message_id: event.id,
                        channel_id: event.channel_id,
                        guild_id: event.guild_id,
                        fail_if_not_exists: false
                    )
                )
            ).raw
            if !(200..<300).contains(apiResponse.status.code) {
                logger.error("Received non-200 status from Discord API: \(apiResponse)")
            }
        } catch {
            logger.error("Discord Client error: \(error)")
        }
    }
    
}
