@testable import DiscordBM
import XCTest

public actor FakeResponseStorage {
    
    private var continuations = Continuations()
    private var unhandledResponses = UnhandledResponses()
    
    public init() { }
    public static var shared = FakeResponseStorage()
    
    public func awaitResponse(
        at endpoint: Endpoint,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> Any {
        await withCheckedContinuation { continuation in
            self.expect(at: endpoint, continuation: continuation, file: file, line: line)
        }
    }
    
    nonisolated func expect(
        at endpoint: Endpoint,
        continuation: CheckedContinuation<Any, Never>,
        file: StaticString,
        line: UInt
    ) {
        Task {
            await _expect(at: endpoint, continuation: continuation, file: file, line: line)
        }
    }
    
    private func _expect(
        at endpoint: Endpoint,
        continuation: CheckedContinuation<Any, Never>,
        file: StaticString,
        line: UInt
    ) {
        if let response = unhandledResponses.retrieve(endpoint: endpoint) {
            continuation.resume(returning: response)
        } else {
            let id = UUID()
            continuations.append(endpoint: endpoint, id: id, continuation: continuation)
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                if continuations.retrieve(id: id) != nil {
                    XCTFail(
                        "Penny did not respond in-time at '\(endpoint.testingKey)'. continuations: \(continuations) | unhandledResponses: \(unhandledResponses)",
                        file: file,
                        line: line
                    )
                    continuation.resume(with: .success(Optional<Never>.none as Any))
                }
            }
        }
    }
    
    /// Used to notify this storage that a response have been received.
    func respond(to endpoint: Endpoint, with payload: Any) {
        if let continuation = continuations.retrieve(endpoint: endpoint) {
            continuation.resume(returning: payload)
        } else {
            unhandledResponses.append(endpoint: endpoint, payload: payload)
        }
    }
}

private struct Continuations: CustomStringConvertible {
    typealias Cont = CheckedContinuation<Any, Never>
    private var storage: [(endpoint: Endpoint, id: UUID, continuation: Cont)] = []
    
    var description: String {
        "\(storage.map({ (endpoint: $0.endpoint, id: $0.id) }))"
    }
    
    mutating func append(endpoint: Endpoint, id: UUID, continuation: Cont) {
        storage.append((endpoint, id, continuation))
    }
    
    mutating func retrieve(endpoint: Endpoint) -> Cont? {
        if let idx = storage.firstIndex(where: { $0.endpoint.testingKey == endpoint.testingKey }) {
            return storage.remove(at: idx).continuation
        } else {
            return nil
        }
    }
    
    mutating func retrieve(id: UUID) -> Cont? {
        if let idx = storage.firstIndex(where: { $0.id == id }) {
            return storage.remove(at: idx).continuation
        } else {
            return nil
        }
    }
}

private struct UnhandledResponses: CustomStringConvertible {
    private var storage: [(endpoint: Endpoint, payload: Any)] = []
    
    var description: String {
        "\(storage.map({ (endpoint: $0, id: type(of: $1)) }))"
    }
    
    mutating func append(endpoint: Endpoint, payload: Any) {
        storage.append((endpoint, payload))
    }
    
    mutating func retrieve(endpoint: Endpoint) -> Any? {
        if let idx = storage.firstIndex(where: { $0.endpoint.testingKey == endpoint.testingKey }) {
            return storage.remove(at: idx).payload
        } else {
            return nil
        }
    }
}
