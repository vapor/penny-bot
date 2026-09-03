import NIOConcurrencyHelpers

// source: https://github.com/MahdiBM/swift-dns/blob/main/Tests/DNSClientTests/ManualClock.swift

struct ManualClock: Clock {
    struct Instant: InstantProtocol, CustomStringConvertible {
        internal let rawValue: Duration

        internal init(_ rawValue: Duration) {
            self.rawValue = rawValue
        }

        static func < (lhs: ManualClock.Instant, rhs: ManualClock.Instant) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        func advanced(by duration: Duration) -> ManualClock.Instant {
            .init(rawValue + duration)
        }

        func duration(to other: ManualClock.Instant) -> Duration {
            other.rawValue - rawValue
        }

        var description: String {
            "\(rawValue)"
        }
    }

    fileprivate struct Wakeup {
        let generation: Int
        let continuation: UnsafeContinuation<Void, any Error>
        let deadline: Instant
    }

    fileprivate enum Scheduled: Hashable, Comparable, CustomStringConvertible {
        case cancelled(Int)
        case wakeup(Wakeup)

        func hash(into hasher: inout Hasher) {
            switch self {
            case .cancelled(let generation):
                hasher.combine(generation)
            case .wakeup(let wakeup):
                hasher.combine(wakeup.generation)
            }
        }

        var description: String {
            switch self {
            case .cancelled: return "Cancelled wakeup"
            case .wakeup(let wakeup): return "Wakeup at \(wakeup.deadline)"
            }
        }

        static func == (_ lhs: Scheduled, _ rhs: Scheduled) -> Bool {
            switch (lhs, rhs) {
            case (.cancelled(let lhsGen), .cancelled(let rhsGen)):
                return lhsGen == rhsGen
            case (.cancelled(let lhsGen), .wakeup(let rhs)):
                return lhsGen == rhs.generation
            case (.wakeup(let lhs), .cancelled(let rhsGen)):
                return lhs.generation == rhsGen
            case (.wakeup(let lhs), .wakeup(let rhs)):
                return lhs.generation == rhs.generation
            }
        }

        static func < (lhs: ManualClock.Scheduled, rhs: ManualClock.Scheduled) -> Bool {
            switch (lhs, rhs) {
            case (.cancelled(let lhsGen), .cancelled(let rhsGen)):
                return lhsGen < rhsGen
            case (.cancelled(let lhsGen), .wakeup(let rhs)):
                return lhsGen < rhs.generation
            case (.wakeup(let lhs), .cancelled(let rhsGen)):
                return lhs.generation < rhsGen
            case (.wakeup(let lhs), .wakeup(let rhs)):
                return lhs.generation < rhs.generation
            }
        }

        var deadline: Instant? {
            switch self {
            case .cancelled: return nil
            case .wakeup(let wakeup): return wakeup.deadline
            }
        }

        func resume() {
            switch self {
            case .wakeup(let wakeup):
                wakeup.continuation.resume()
            default:
                break
            }
        }
    }

    fileprivate struct State {
        var generation = 0
        var scheduled = Set<Scheduled>()
        var now = Instant(.zero)
        var hasSleepers = false
    }

    fileprivate let state = NIOLockedValueBox(State())

    var now: Instant {
        state.withLockedValue { $0.now }
    }

    var minimumResolution: Duration { .zero }

    init() {}

    fileprivate func cancel(_ generation: Int) {
        state.withLockedValue { state -> UnsafeContinuation<Void, any Error>? in
            guard let existing = state.scheduled.remove(.cancelled(generation)) else {
                // insert the cancelled state for when it comes in to be scheduled as a wakeup
                state.scheduled.insert(.cancelled(generation))
                return nil
            }
            switch existing {
            case .wakeup(let wakeup):
                return wakeup.continuation
            default:
                return nil
            }
        }?.resume(throwing: CancellationError())
    }

    var hasSleepers: Bool {
        state.withLockedValue { $0.hasSleepers }
    }

    func advance(by duration: Duration) {
        let pending = state.withLockedValue { state -> Set<Scheduled> in
            state.now = state.now.advanced(by: duration)
            let pending = state.scheduled.filter { item in
                guard let deadline = item.deadline else {
                    return false
                }
                return deadline <= state.now
            }
            state.scheduled.subtract(pending)
            if pending.count > 0 {
                state.hasSleepers = false
            }
            return pending
        }
        for item in pending.sorted() {
            item.resume()
        }
    }

    fileprivate func schedule(
        _ generation: Int,
        continuation: UnsafeContinuation<Void, any Error>,
        deadline: Instant
    ) {
        let resumption = state.withLockedValue {
            state -> (UnsafeContinuation<Void, any Error>, Result<Void, any Error>)? in
            let wakeup = Wakeup(
                generation: generation,
                continuation: continuation,
                deadline: deadline
            )
            guard let existing = state.scheduled.remove(.wakeup(wakeup)) else {
                // there is no cancelled placeholder so let it run free
                guard deadline > state.now else {
                    // the deadline is now or in the past so run it immediately
                    return (continuation, .success(()))
                }
                // the deadline is in the future so run it then
                state.hasSleepers = true
                state.scheduled.insert(.wakeup(wakeup))
                return nil
            }
            switch existing {
            case .wakeup:
                fatalError()
            case .cancelled:
                // dont bother adding it back because it has been cancelled before we got here
                return (continuation, .failure(CancellationError()))
            }
        }
        if let resumption = resumption {
            resumption.0.resume(with: resumption.1)
        }
    }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        let generation = state.withLockedValue { state -> Int in
            defer { state.generation += 1 }
            return state.generation
        }
        try await withTaskCancellationHandler {
            try await withUnsafeThrowingContinuation { continuation in
                schedule(generation, continuation: continuation, deadline: deadline)
            }
        } onCancel: {
            cancel(generation)
        }
    }
}
