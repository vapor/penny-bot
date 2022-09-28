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
                await MessageHandler(
                    discordClient: discordClient,
                    coinService: coinService,
                    logger: logger,
                    event: message
                )
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
}
