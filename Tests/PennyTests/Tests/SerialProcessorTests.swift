import Shared
import Testing

/// Intentionally `nonisolated(unsafe)` to test concurrent access.
nonisolated(unsafe) private var dict = [String: [Int]]()

struct SerialProcessorTests {
    @Test
    func concurrentProcessing() async throws {
        let processor = SerialProcessor(queueLimit: .max)
        let range = 0..<10_000

        try await withThrowingDiscardingTaskGroup { taskGroup in
            for idx in range {
                taskGroup.addTask {
                    try await processor.process(queueKey: "test") {
                        dict["a", default: []].append(idx)
                    }
                }
            }
        }

        /// `.sorted()` because the order is not guaranteed.
        #expect(dict["a"]?.sorted() == Array(range))
    }
}
