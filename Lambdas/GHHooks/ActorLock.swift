
actor ActorLock {
    private var isLocked = false
    private var lockWaiters: [CheckedContinuation<Void, Never>] = []

    /// Acquires a lock and performs the async work, then releases the lock.
    func withLock<T>(block: @Sendable () async throws -> T) async rethrows -> T {
        while isLocked {
            await withCheckedContinuation { continuation in
                lockWaiters.append(continuation)
            }
        }

        isLocked = true
        defer {
            isLocked = false
            lockWaiters.popLast()?.resume()
        }

        return try await block()
    }
}
