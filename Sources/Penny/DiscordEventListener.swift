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
            }

            taskGroup.addTask {
                for await event in await self.bot.events.cancelOnGracefulShutdown() {
                    if case .ready = event.data {
                        await self.afterConnect()
                    }

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

    /// Only needs to be triggered for the first connection
    private func afterConnect() {
        if self.isConnected { return }
        for continuation in self.connectionWaiterContinuations {
            continuation.resume()
        }
        self.connectionWaiterContinuations.removeAll()
        self.isConnected = true
    }
}
