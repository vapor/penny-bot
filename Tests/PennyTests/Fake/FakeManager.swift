@testable import Penny
import struct NIOCore.ByteBuffer
import DiscordBM
import Atomics
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing

actor FakeManager: GatewayManager {
    nonisolated let client: any DiscordClient = FakeDiscordClient()
    nonisolated let id: UInt = 0
    nonisolated let identifyPayload: Gateway.Identify = .init(token: "", intents: [])
    var eventContinuations = [AsyncStream<Gateway.Event>.Continuation]()
    
    init() { }
    
    func connect() async { }

    func requestGuildMembersChunk(payload: Gateway.RequestGuildMembers) async { }
    func updatePresence(payload: Gateway.Identify.Presence) async { }
    func updateVoiceState(payload: VoiceStateUpdate) async { }
    func makeEventsStream() async -> AsyncStream<Gateway.Event> {
        AsyncStream { continuation in
            eventContinuations.append(continuation)
        }
    }
    func makeEventsParseFailureStream() async -> AsyncStream<(any Error, ByteBuffer)> {
        AsyncStream { _ in }
    }
    func disconnect() { }

    func send(event: Gateway.Event) {
        for continuation in eventContinuations {
            continuation.yield(event)
        }
    }

    func send(key: EventKey) {
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
    func sendAndAwaitResponse<T>(
        key: EventKey,
        endpoint: APIEndpoint? = nil,
        as type: T.Type = T.self,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) async throws -> T {
        try await self.sendAndAwaitResponse(
            key: key,
            endpoint: endpoint.map { .api($0) },
            as: T.self,
            sourceLocation: sourceLocation
        )
    }
    
    func sendAndAwaitResponse<T>(
        key: EventKey,
        endpoint: AnyEndpoint? = nil,
        as type: T.Type = T.self,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) async throws -> T {
        let box = await withCheckedContinuation {
            (continuation: CheckedContinuation<AnyBox, Never>) in
            FakeResponseStorage.shared.expect(
                at: endpoint ?? .api(key.responseEndpoints[0]),
                continuation: continuation,
                sourceLocation: sourceLocation
            )
            self.send(key: key)
        }
        let unwrapped = try #require(
            box.value as? T,
            "Value '\(box.value)' can't be cast to '\(_typeName(T.self))'",
            sourceLocation: sourceLocation
        )
        return unwrapped
    }
}
