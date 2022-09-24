import Foundation
import DiscordBM
import PennyModels
import Logging
import AsyncHTTPClient

struct EventHandler {
    let event: Gateway.Event
    let discordClient: DiscordClient
    let coinService: CoinService
    let logger: Logger
    
    func handle() {
        Task {
            switch event.data {
            case .messageCreate(let message):
                await onMessageCreate(event: message)
            case .interactionCreate(let interaction):
                await InteractionHandler(
                    discordClient: discordClient,
                    logger: logger,
                    event: interaction
                ).handle()
            case .messageReactionAdd(let reaction):
                await ReactionHandler(
                    discordClient: discordClient,
                    coinService: coinService,
                    logger: logger,
                    event: reaction
                ).handle()
            default: break
            }
        }
    }
    
    func onMessageCreate(event: Gateway.Message) async {
        // Stop the bot from responding to other bots and itself
        if event.member?.user?.bot == true {
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
            
            let oops = "Oops. Something went wrong! Please try again later"
            let response: String
            do {
                response = try await self.coinService.postCoin(with: coinRequest)
            } catch {
                return await respondToMessage(with: oops, channelId: event.channel_id)
            }
            if response.starts(with: "ERROR-") {
                logger.error("Received an incoming error: \(response)")
                await respondToMessage(with: oops, channelId: event.channel_id)
            } else {
                await respondToMessage(with: response, channelId: event.channel_id)
            }
        }
    }
    
    private func respondToMessage(with response: String, channelId: String) async {
        do {
            let apiResponse = try await discordClient.createMessage(
                channelId: channelId,
                payload: .init(content: response)
            ).raw
            if !(200..<300).contains(apiResponse.status.code) {
                logger.error("Received non-200 status from Discord API: \(apiResponse)")
            }
        } catch {
            logger.error("Discord Client error: \(error)")
        }
    }
}
