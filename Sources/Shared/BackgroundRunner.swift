import ServiceLifecycle
import Synchronization

package final class BackgroundRunner: Service {
    package typealias WorkItem = @Sendable () async -> Void
    private let stream: AsyncStream<WorkItem>
    private let continuation: AsyncStream<WorkItem>.Continuation
    private let isRunning = Mutex(false)

    package init() {
        (stream, continuation) = AsyncStream.makeStream(
            of: WorkItem.self,
            bufferingPolicy: .unbounded
        )
    }

    package func run() async {
        self.isRunning.withLock { $0 = true }
        await withDiscardingTaskGroup { taskGroup in
            for await work in self.stream.cancelOnGracefulShutdown() {
                taskGroup.addTask {
                    await work()
                }
            }

            taskGroup.cancelAll()
        }
    }

    package func process(_ workItem: @escaping WorkItem) {
        self.continuation.yield(workItem)
    }
}
