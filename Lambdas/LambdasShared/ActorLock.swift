import Collections

public actor SerialProcessor {

    enum Errors: Error, CustomStringConvertible {
        case overloaded(limit: Int)

        var description: String {
            switch self {
            case .overloaded(let limit):
                return "overloaded(limit: \(limit))"
            }
        }
    }

    private var isRunning = false
    private var queue: Deque<CheckedContinuation<Void, Never>> = []
    private let limit: Int

    public init(queueLimit: Int = 50) {
        self.limit = queueLimit
    }

    public func process<T>(block: @Sendable () async throws -> T) async throws -> T {
        guard queue.count < limit else {
            throw Errors.overloaded(limit: limit)
        }

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
