import ServiceLifecycle
import Synchronization

final class BackgroundRunner: Service {
    typealias WorkItem = @Sendable () async -> Void
    private let stream: AsyncStream<WorkItem>
    private let continuation: Mutex<AsyncStream<WorkItem>.Continuation>

    init() {
        let (stream, continuation) = AsyncStream.makeStream(
            of: WorkItem.self,
            bufferingPolicy: .unbounded
        )
        self.stream = stream
        self.continuation = Mutex(continuation)
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
        _ = self.continuation.withLock {
            $0.yield(workItem)
        }
    }
}
