import Shared
import Testing

/// Intentionally `nonisolated(unsafe)` to test concurrent access.
nonisolated(unsafe) private var dict = [String: [Int]]()

struct SerialProcessorTests {
    @Test
    func concurrentProcessing() async throws {
        let processor = SerialProcessor(queueLimit: .max)

        try await withThrowingDiscardingTaskGroup { taskGroup in
            for idx in 0 ..< 1000 {
                taskGroup.addTask {
                    try await processor.process(queueKey: "test") {
                        dict["a", default: []].append(idx)
                    }
                }
            }
        }

        #expect(dict["a"]?.sorted() == Array(0 ..< 1000))
    }
}
