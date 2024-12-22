import Shared

@Suite(.serialized)
struct SerialProcessorTests {
    @Test
    func concurrentProcessing() async throws {
        let processor = SerialProcessor(queueLimit: .max)
        nonisolated(unsafe) var dict = [String: [Int]]()

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
