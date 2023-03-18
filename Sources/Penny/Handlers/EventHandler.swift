import DiscordBM
import Logging

struct EventHandler: Sendable {
    let event: Gateway.Event
    let coinService: any CoinService
    let logger = Logger(label: "EventHandler")
    
    func handle() {
        Task {
            guard await BotStateManager.shared.canRespond(to: event) else {
                logger.debug("BotStateManager doesn't allow responding", metadata: [
                    "event": "\(event)"
                ])
                return
            }
            switch event.data {
            case .messageCreate(let message):
                await ReactionCache.shared.invalidateCachesIfNeeded(event: message)
                await MessageHandler(
                    coinService: coinService,
                    event: message
                ).handle()
            case .interactionCreate(let interaction):
                await InteractionHandler(
                    event: interaction,
                    coinService: coinService
                ).handle()
            case .messageReactionAdd(let reaction):
                await ReactionHandler(
                    coinService: coinService,
                    event: reaction
                ).handle()
            default: break
            }
        }
    }
}
