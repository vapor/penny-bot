import DiscordBM
import ServiceLifecycle

struct DiscordEventListener: Service {
    let bot: any GatewayManager
    let context: HandlerContext

    func run() async {
        await withDiscardingTaskGroup { taskGroup in
            for await event in await bot.events.cancelOnGracefulShutdown() {
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
