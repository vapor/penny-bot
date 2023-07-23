import DiscordBM
import Logging

struct EventHandler: GatewayEventHandler {
    let event: Gateway.Event
    let logger = Logger(label: "EventHandler")
    
    func onEventHandlerStart() async -> Bool {
        let canRespond = await BotStateManager.shared.canRespond(to: event)
        if !canRespond {
            logger.debug("BotStateManager doesn't allow responding to event", metadata: [
                "event": "\(event)"
            ])
        }
        return canRespond
    }
    
    func onMessageCreate(_ message: Gateway.MessageCreate) async {
        await MessageHandler(event: message).handle()
    }
    
    func onInteractionCreate(_ interaction: Interaction) async {
        await InteractionHandler(event: interaction).handle()
    }
    
    func onMessageReactionAdd(_ reaction: Gateway.MessageReactionAdd) async {
        #warning("revert")
        return
        await ReactionHandler(event: reaction).handle()
    }
}
