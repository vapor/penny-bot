@testable import DiscordBM
import Atomics
import Testing

actor FakeResponseStorage {
    
    private var continuations = Continuations()
    private var unhandledResponses = UnhandledResponses()

    init() { }
    static var shared = FakeResponseStorage()

    private static let idGenerator = ManagedAtomic(UInt(0))

    func awaitResponse(
        at endpoint: APIEndpoint,
        expectFailure: Bool = false,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) async -> AnyBox {
        await withCheckedContinuation { continuation in
            self.expect(
                at: .api(endpoint),
                expectFailure: expectFailure,
                continuation: continuation,
                sourceLocation: sourceLocation
            )
        }
    }
    
    func awaitResponse(
        at endpoint: AnyEndpoint,
        expectFailure: Bool = false,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) async -> AnyBox {
        await withCheckedContinuation { continuation in
            self.expect(
                at: endpoint,
                expectFailure: expectFailure,
                continuation: continuation,
                sourceLocation: sourceLocation
            )
        }
    }
    
    nonisolated func expect(
        at endpoint: AnyEndpoint,
        expectFailure: Bool = false,
        continuation: CheckedContinuation<AnyBox, Never>,
        sourceLocation: Testing.SourceLocation
    ) {
        Task {
            await _expect(
                at: endpoint,
                expectFailure: expectFailure,
                continuation: continuation,
                sourceLocation: sourceLocation
            )
        }
    }
    
    private func _expect(
        at endpoint: any Endpoint,
        expectFailure: Bool = false,
        continuation: CheckedContinuation<AnyBox, Never>,
        sourceLocation: Testing.SourceLocation
    ) {
        if let response = unhandledResponses.retrieve(endpoint: endpoint) {
            if expectFailure {
                Issue.record(
                    "Was expecting a failure at '\(endpoint.testingKey)'. continuations: \(continuations) | unhandledResponses: \(unhandledResponses)",
                    sourceLocation: sourceLocation
                )
                continuation.resume(returning: AnyBox(Optional<Never>.none as Any))
            } else {
                continuation.resume(returning: response)
            }
        } else {
            let id = Self.idGenerator.loadThenWrappingIncrement(ordering: .relaxed)
            continuations.append(endpoint: endpoint, id: id, continuation: continuation)
            Task {
                try await Task.sleep(for: .seconds(3))
                if continuations.retrieve(id: id) != nil {
                    if !expectFailure {
                        Issue.record(
                            "Penny did not respond in-time at '\(endpoint.testingKey)'. continuations: \(continuations) | unhandledResponses: \(unhandledResponses)",
                            sourceLocation: sourceLocation
                        )
                    }
                    continuation.resume(with: .success(AnyBox(Optional<Never>.none as Any)))
                    return
                } else {
                    if expectFailure {
                        Issue.record(
                            "Expected a failure at '\(endpoint.testingKey)'. continuations: \(continuations) | unhandledResponses: \(unhandledResponses)",
                            sourceLocation: sourceLocation
                        )
                    }
                }
            }
        }
    }
    
    /// Used to notify this storage that a response have been received.
    func respond(to endpoint: any Endpoint, with payload: AnyBox) {
        if let continuation = continuations.retrieve(endpoint: endpoint) {
            continuation.resume(returning: payload)
        } else {
            unhandledResponses.append(endpoint: endpoint, payload: payload)
        }
    }
}

private struct Continuations: CustomStringConvertible {

    enum Action: String, CustomStringConvertible {
        case add, removeByEndpoint, removeById

        var description: String {
            self.rawValue
        }
    }

    typealias Cont = CheckedContinuation<AnyBox, Never>
    
    private var storage: [(endpoint: any Endpoint, id: UInt, continuation: Cont)] = []
    /// History for debugging purposes
    private var history: [(endpoint: any Endpoint, id: UInt, action: Action)] = []

    var description: String {
        "Continuations(" +
        "storage: \(storage.map({ (endpoint: $0.endpoint, id: $0.id) })), " +
        "history: \(history)" +
        ")"
    }
    
    mutating func append(endpoint: any Endpoint, id: UInt, continuation: Cont) {
        storage.append((endpoint, id, continuation))
        history.append((endpoint, id, .add))
    }
    
    mutating func retrieve(endpoint: any Endpoint) -> Cont? {
        if let idx = storage.firstIndex(where: { $0.endpoint.testingKey == endpoint.testingKey }) {
            let removed = storage.remove(at: idx)
            history.append((endpoint, removed.id, .removeByEndpoint))
            return removed.continuation
        } else {
            return nil
        }
    }
    
    mutating func retrieve(id: UInt) -> Cont? {
        if let idx = storage.firstIndex(where: { $0.id == id }) {
            let removed = storage.remove(at: idx)
            history.append((removed.endpoint, id, .removeById))
            return removed.continuation
        } else {
            return nil
        }
    }
}

private struct UnhandledResponses: CustomStringConvertible {
    private var storage: [(endpoint: any Endpoint, payload: AnyBox)] = []
    
    var description: String {
        "\(storage.map({ (endpoint: $0, payloadType: type(of: $1.value)) }))"
    }
    
    mutating func append(endpoint: any Endpoint, payload: AnyBox) {
        storage.append((endpoint, payload))
    }
    
    mutating func retrieve(endpoint: any Endpoint) -> AnyBox? {
        if let idx = storage.firstIndex(where: { $0.endpoint.testingKey == endpoint.testingKey }) {
            return storage.remove(at: idx).payload
        } else {
            return nil
        }
    }
}
