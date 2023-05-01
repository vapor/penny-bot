import DiscordBM
@testable import PennyBOT
import Atomics
import struct NIOCore.ByteBuffer
import XCTest

public actor FakeManager: GatewayManager {
    public nonisolated let client: any DiscordClient = FakeDiscordClient()
    public nonisolated let id: UInt = 0
    let _state = ManagedAtomic<GatewayState>(.noConnection)
    /// This `nonisolated var state` is just for protocol conformance
    public nonisolated var state: GatewayState {
        self._state.load(ordering: .relaxed)
    }
    var eventContinuations = [AsyncStream<Gateway.Event>.Continuation]()
    
    public init() { }
    
    public func connect() {
        self._state.store(.connected, ordering: .relaxed)
        connectionWaiter?.resume()
    }

    public func requestGuildMembersChunk(payload: Gateway.RequestGuildMembers) async { }
    public func updatePresence(payload: Gateway.Identify.Presence) async { }
    public func updateVoiceState(payload: VoiceStateUpdate) async { }
    public func makeEventsStream() async -> AsyncStream<Gateway.Event> {
        AsyncStream { continuation in
            eventContinuations.append(continuation)
        }
    }
    public func makeEventsParseFailureStream() async -> AsyncStream<(Error, ByteBuffer)> {
        AsyncStream { _ in }
    }
    public func disconnect() { }
    
    var connectionWaiter: CheckedContinuation<(), Never>?
    
    public func waitUntilConnected() async {
        if self.state == .connected {
            return
        } else {
            await withCheckedContinuation {
                self.connectionWaiter = $0
            }
        }
    }
    
    public func send(key: EventKey) {
        let data = TestData.for(key: key.rawValue)!
        let decoder = JSONDecoder()
        let event = try! decoder.decode(Gateway.Event.self, from: data)
        for continuation in eventContinuations {
            continuation.yield(event)
        }
    }
    
    @_disfavoredOverload
    public func sendAndAwaitResponse<T>(
        key: EventKey,
        endpoint: APIEndpoint? = nil,
        as type: T.Type = T.self,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> T {
        try await self.sendAndAwaitResponse(
            key: key,
            endpoint: endpoint.map { .api($0) },
            as: T.self,
            file: file,
            line: line
        )
    }
    
    public func sendAndAwaitResponse<T>(
        key: EventKey,
        endpoint: AnyEndpoint? = nil,
        as type: T.Type = T.self,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> T {
        let box = await withCheckedContinuation {
            (continuation: CheckedContinuation<AnyBox, Never>) in
            FakeResponseStorage.shared.expect(
                at: endpoint ?? .api(key.responseEndpoints[0]),
                continuation: continuation,
                file: file,
                line: line
            )
            self.send(key: key)
        }
        let unwrapped = try XCTUnwrap(
            box.value as? T,
            "Value '\(box.value)' can't be cast to '\(_typeName(T.self))'",
            file: file,
            line: line
        )
        return unwrapped
    }
}
