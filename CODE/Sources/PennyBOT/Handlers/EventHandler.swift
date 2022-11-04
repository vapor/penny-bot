import DiscordBM
import Logging

struct EventHandler {
    let event: Gateway.Event
    let discordClient: any DiscordClient
    let coinService: any CoinService
    let logger: Logger
    
    func handle() {
        Task {
            guard await BotStateManager.shared.canRespond(to: event) else {
                logger.debug("BotStateManager doesn't allow responding to event", metadata: [
                    "event": "\(event)"
                ])
                return
            }
            switch event.data {
            case .messageCreate(let message):
                await MessageHandler(
                    discordClient: discordClient,
                    coinService: coinService,
                    logger: logger,
                    event: message
                ).handle()
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
}
