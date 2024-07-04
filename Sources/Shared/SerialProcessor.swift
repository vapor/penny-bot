import Collections

package actor SerialProcessor {

    enum Errors: Error, CustomStringConvertible {
        case overloaded(limit: Int)

        var description: String {
            switch self {
            case .overloaded(let limit):
                return "overloaded(limit: \(limit))"
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

    package func process<T: Sendable>(
        queueKey: String,
        block: @Sendable () async throws -> T
    ) async throws -> T {
        guard queue[queueKey].map({ $0.count <= limit }) ?? true else {
            throw Errors.overloaded(limit: limit)
        }

        if isRunning[queueKey, default: false] {
            await withCheckedContinuation { continuation in
                queue[queueKey, default: []].append(continuation)
            }
        }

        precondition(!isRunning[queueKey, default: false])
        isRunning[queueKey] = true
        defer {
            isRunning[queueKey] = false
            queue[queueKey]?.popFirst()?.resume()
        }

        return try await block()
    }
}
