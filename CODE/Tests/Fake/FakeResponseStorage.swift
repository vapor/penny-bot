@testable import DiscordBM
import Atomics
import XCTest

public actor FakeResponseStorage {
    
    private var continuations = Continuations()
    private var unhandledResponses = UnhandledResponses()
    
    public init() { }
    public static var shared = FakeResponseStorage()

    private static let idGenerator = ManagedAtomic(UInt(0))

    public func awaitResponse(
        at endpoint: APIEndpoint,
        expectFailure: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> AnyBox {
        await withCheckedContinuation { continuation in
            self.expect(
                at: .api(endpoint),
                expectFailure: expectFailure,
                continuation: continuation,
                file: file,
                line: line
            )
        }
    }
    
    public func awaitResponse(
        at endpoint: AnyEndpoint,
        expectFailure: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> AnyBox {
        await withCheckedContinuation { continuation in
            self.expect(
                at: endpoint,
                expectFailure: expectFailure,
                continuation: continuation,
                file: file,
                line: line
            )
        }
    }
    
    nonisolated func expect(
        at endpoint: AnyEndpoint,
        expectFailure: Bool = false,
        continuation: CheckedContinuation<AnyBox, Never>,
        file: StaticString,
        line: UInt
    ) {
        Task {
            await _expect(
                at: endpoint,
                expectFailure: expectFailure,
                continuation: continuation,
                file: file,
                line: line
            )
        }
    }
    
    private func _expect(
        at endpoint: any Endpoint,
        expectFailure: Bool = false,
        continuation: CheckedContinuation<AnyBox, Never>,
        file: StaticString,
        line: UInt
    ) {
        if let response = unhandledResponses.retrieve(endpoint: endpoint) {
            if expectFailure {
                XCTFail("Was expecting a failure at '\(endpoint.testingKey)'. continuations: \(continuations) | unhandledResponses: \(unhandledResponses)", file: file, line: line)
            } else {
                continuation.resume(returning: response)
            }
        } else {
            let id = Self.idGenerator.loadThenWrappingIncrement(ordering: .relaxed)
            continuations.append(endpoint: endpoint, id: id, continuation: continuation)
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                if continuations.retrieve(id: id) != nil {
                    if !expectFailure {
                        XCTFail(
                            "Penny did not respond in-time at '\(endpoint.testingKey)'. continuations: \(continuations) | unhandledResponses: \(unhandledResponses)",
                            file: file,
                            line: line
                        )
                    }
                    continuation.resume(with: .success(AnyBox(Optional<Never>.none as Any)))
                    return
                } else {
                    if expectFailure {
                        XCTFail(
                            "Expected a failure at '\(endpoint.testingKey)'. continuations: \(continuations) | unhandledResponses: \(unhandledResponses)",
                            file: file,
                            line: line
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
