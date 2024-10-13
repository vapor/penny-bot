import DiscordBM
import ServiceLifecycle

struct DiscordEventListener: Service {
    let bot: any GatewayManager
    let context: HandlerContext

    func run() async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for await event in await bot.events {
                taskGroup.addTask {
                    await EventHandler(
                        event: event,
                        context: context
                    ).handleAsync()
                }
            }

            taskGroup.cancelAll()
        }
    }
}
