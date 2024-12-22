import Collections

/// Provides an _async_ locking mechanism for each key.
package actor SerialProcessor {
    enum Errors: Error, CustomStringConvertible {
        case overloaded(limit: Int)

        var description: String {
            switch self {
            case let .overloaded(limit):
                "overloaded(limit: \(limit))"
            }
        }
    }

    /// `[QueueKey: IsRunning]`
    private var isRunning: [String: Bool] = [:]
    /// `[QueueKey: Deque<Continuation>]`
    private var queue: [String: Deque<CheckedContinuation<Void, Never>>] = [:]
    private let limit: Int

    package init(queueLimit: Int = 10) {
        self.limit = queueLimit
    }

    /// Process the `block` in the `key` serial-queue.
    package func process<T: Sendable>(
        queueKey: String,
        block: @Sendable () async throws -> T
    ) async throws -> T {
        guard self.queue[queueKey].map({ $0.count <= self.limit }) ?? true else {
            throw Errors.overloaded(limit: self.limit)
        }

        switch self.isRunning[queueKey, default: false] {
        case false:
            precondition(!self.isRunning[queueKey, default: false])
            self.isRunning[queueKey] = true
        case true:
            await withCheckedContinuation { continuation in
                self.queue[queueKey, default: []].append(continuation)
            }
        }

        let result = try await block()

        if let first = self.queue[queueKey]?.popFirst() {
            first.resume()
        } else {
            self.isRunning[queueKey] = false
        }

        return result
    }
}
