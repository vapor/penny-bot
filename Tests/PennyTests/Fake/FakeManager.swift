import DiscordBM
@testable import Penny
import Atomics
import struct NIOCore.ByteBuffer
import XCTest

package actor FakeManager: GatewayManager {
    package nonisolated let client: any DiscordClient = FakeDiscordClient()
    package nonisolated let id: UInt = 0
    package nonisolated let identifyPayload: Gateway.Identify = .init(token: "", intents: [])
    var eventContinuations = [AsyncStream<Gateway.Event>.Continuation]()
    
    package init() { }
    
    package func connect() async { }

    package func requestGuildMembersChunk(payload: Gateway.RequestGuildMembers) async { }
    package func updatePresence(payload: Gateway.Identify.Presence) async { }
    package func updateVoiceState(payload: VoiceStateUpdate) async { }
    package func makeEventsStream() async -> AsyncStream<Gateway.Event> {
        AsyncStream { continuation in
            eventContinuations.append(continuation)
        }
    }
    package func makeEventsParseFailureStream() async -> AsyncStream<(any Error, ByteBuffer)> {
        AsyncStream { _ in }
    }
    package func disconnect() { }

    package func send(event: Gateway.Event) {
        for continuation in eventContinuations {
            continuation.yield(event)
        }
    }

    package func send(key: EventKey) {
        let data = TestData.for(gatewayEventKey: key.rawValue)!
        let decoder = JSONDecoder()
        let event: Gateway.Event
        do {
            event = try decoder.decode(Gateway.Event.self, from: data)
        } catch {
            fatalError("Failed to get event: '\(key)'. Error: \(error)")
        }
        for continuation in eventContinuations {
            continuation.yield(event)
        }
    }
    
    @_disfavoredOverload
    package func sendAndAwaitResponse<T>(
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
    
    package func sendAndAwaitResponse<T>(
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
