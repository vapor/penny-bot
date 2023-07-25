import DiscordBM
import Logging

struct EventHandler: GatewayEventHandler {
    let event: Gateway.Event
    let context: HandlerContext
    let logger = Logger(label: "EventHandler")
    
    func onEventHandlerStart() async -> Bool {

        let canRespond = await context.botStateManager.canRespond(to: event)
        if !canRespond {
            logger.debug("BotStateManager doesn't allow responding to event", metadata: [
                "event": "\(event)"
            ])
        }
        return canRespond
    }
    
    func onMessageCreate(_ message: Gateway.MessageCreate) async {
        await MessageHandler(event: message, context: context).handle()
    }
    
    func onInteractionCreate(_ interaction: Interaction) async {
        await InteractionHandler(event: interaction, context: context).handle()
    }
    
    func onMessageReactionAdd(_ reaction: Gateway.MessageReactionAdd) async {
        await ReactionHandler(event: reaction, context: context).handle()
    }
}
