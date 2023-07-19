import Collections

actor SerialProcessor {
    private var isRunning = false
    private var queue: Deque<CheckedContinuation<Void, Never>> = []

    func process<T>(block: @Sendable () async throws -> T) async rethrows -> T {
        if isRunning {
            await withCheckedContinuation { continuation in
                queue.append(continuation)
            }
        }

        precondition(!isRunning)
        isRunning = true
        defer {
            isRunning = false
            queue.popFirst()?.resume()
        }

        return try await block()
    }
}
