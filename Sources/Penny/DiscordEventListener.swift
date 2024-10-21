import DiscordBM
import ServiceLifecycle

actor DiscordEventListener: Service {
    let bot: any GatewayManager
    let context: HandlerContext

    private var connectionWaiterContinuations: [CheckedContinuation<Void, Never>] = []
    private var isConnected = false

    init(bot: any GatewayManager, context: HandlerContext) {
        self.bot = bot
        self.context = context
    }

    func run() async {
        await withDiscardingTaskGroup { taskGroup in
            taskGroup.addTask {
                await self.bot.connect()
                await self.afterConnect()
            }

            for await event in await bot.events.cancelOnGracefulShutdown() {
                taskGroup.addTask {
                    await EventHandler(
                        event: event,
                        context: self.context
                    ).handleAsync()
                }
            }

            taskGroup.cancelAll()
        }
    }

    func addConnectionWaiterContinuation(_ cont: CheckedContinuation<Void, Never>) {
        switch self.isConnected {
        case true:
            cont.resume()
        case false:
            self.connectionWaiterContinuations.append(cont)
        }
    }

    private func afterConnect() {
        for continuation in self.connectionWaiterContinuations {
            continuation.resume()
        }
        self.connectionWaiterContinuations.removeAll()
        self.isConnected = true
    }
}
