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
            default: break
            }
        }
    }
    
    func onMessageCreate(event: Gateway.Message) async {
        guard let author = event.author else {
            logger.error("Cannot find author of the message. Event: \(event)")
            return
        }
        // Stop the bot from responding to other bots and itself
        if event.member?.user?.bot == true {
            return
        }
        
        let sender = "<@\(author.id)>"
        let coinHandler = CoinHandler(
            text: event.content,
            excludedUsers: [sender] // Can't give yourself a coin
        )
        let usersWithNewCoins = coinHandler.findUsers()
        // If there are no coins to be granted, then return.
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
                if response.starts(with: "ERROR-") {
                    logger.error("CoinService returned. Request: \(coinRequest), Response: \(response)")
                } else {
                    successfulResponses.append(response)
                }
            } catch {
                logger.error("CoinService failed. Request: \(coinRequest), Error: \(error)")
            }
        }
        
        if successfulResponses.isEmpty {
            // Definitely there were some coin requests that failed.
            await self.createMessage(
                "Oops. Something went wrong! Please try again later",
                in: event.channel_id
            )
        } else {
            // Stitch responses together instead of sending a lot of messages,
            // to consume less Discord rate-limit.
            let finalResponse = successfulResponses.joined(separator: "\n")
            // Discord doesn't like messages with more than 2_000 content length.
            if finalResponse.unicodeScalars.count > 2_000 {
                await self.createMessage(
                    "Coins were granted to a lot of members!",
                    in: event.channel_id
                )
            } else {
                await self.createMessage(finalResponse, in: event.channel_id)
            }
        }
    }
    
    private func createMessage(_ response: String, in channelId: String) async {
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
