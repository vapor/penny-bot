import ServiceLifecycle
import Synchronization

package final class BackgroundProcessor: Service {
    package typealias WorkItem = @Sendable () async -> Void
    private let stream: AsyncStream<WorkItem>
    private let continuation: AsyncStream<WorkItem>.Continuation

    package init() {
        (stream, continuation) = AsyncStream.makeStream(
            of: WorkItem.self,
            bufferingPolicy: .unbounded
        )
    }

    package func run() async {
        await withTaskGroup(of: Void.self) { taskGroup in
            let maxConcurrentTasks = 8
            let workIndex = Atomic(UInt(0))

            for await work in self.stream.cancelOnGracefulShutdown() {
                let index = workIndex.add(1, ordering: .relaxed).oldValue
                if index >= maxConcurrentTasks {
                    /// Wait for the next task first,
                    /// as a way of limiting how many tasks are concurrently run
                    _ = await taskGroup.next()
                }
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
