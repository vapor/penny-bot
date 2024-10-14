import ServiceLifecycle
import Synchronization

final class BackgroundRunner: Service {
    typealias WorkItem = @Sendable () async -> Void
    private let stream: AsyncStream<WorkItem>
    private let continuation: AsyncStream<WorkItem>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(
            of: WorkItem.self,
            bufferingPolicy: .unbounded
        )
    }

    func run() async {
        await withDiscardingTaskGroup { taskGroup in
            for await work in self.stream.cancelOnGracefulShutdown() {
                taskGroup.addTask {
                    await work()
                }
            }

            taskGroup.cancelAll()
        }
    }

    func process(_ workItem: @escaping WorkItem) {
        self.continuation.yield(workItem)
    }
}
