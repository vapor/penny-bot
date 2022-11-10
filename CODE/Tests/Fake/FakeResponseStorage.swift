@testable import DiscordBM
import XCTest

public actor FakeResponseStorage {
    
    private var continuations = [String: CheckedContinuation<Any, Never>]()
    private var unhandledResponses = [String: Any]()
    
    public init() { }
    public static var shared = FakeResponseStorage()
    
    public func awaitResponse(at endpoint: Endpoint) async -> Any {
        await withCheckedContinuation { continuation in
            self.expect(at: endpoint, continuation: continuation)
        }
    }
    
    private func expect(at endpoint: Endpoint, continuation: CheckedContinuation<Any, Never>) {
        if let response = unhandledResponses[endpoint.urlSuffix] {
            continuation.resume(returning: response)
        } else {
            continuations[endpoint.urlSuffix] = continuation
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                if continuations.removeValue(forKey: endpoint.urlSuffix) != nil {
                    XCTFail("Penny did not respond in-time at '\(endpoint.urlSuffix)'")
                    continuation.resume(with: .success(Optional<Never>.none as Any))
                }
            }
        }
    }
    
    /// Used to notify this storage that a response have been received.
    func respond(to endpoint: Endpoint, with payload: Any) {
        if let continuation = continuations.removeValue(forKey: endpoint.urlSuffix) {
            continuation.resume(returning: payload)
        } else {
            unhandledResponses[endpoint.urlSuffix] = payload
        }
    }
}
