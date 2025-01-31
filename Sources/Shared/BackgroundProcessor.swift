import ServiceLifecycle

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
