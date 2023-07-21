import Collections

public actor SerialProcessor {
    private var isRunning = false
    private var queue: Deque<CheckedContinuation<Void, Never>> = []

    public init() { }

    public func process<T>(block: @Sendable () async throws -> T) async rethrows -> T {
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
