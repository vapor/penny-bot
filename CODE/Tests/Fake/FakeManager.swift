import DiscordBM
@testable import PennyBOT
import Atomics
import struct NIOCore.ByteBuffer
import XCTest

public actor FakeManager: GatewayManager {
    public nonisolated let client: any DiscordClient = FakeDiscordClient()
    public nonisolated let id: UInt = 0
    public nonisolated let identifyPayload: Gateway.Identify = .init(token: "", intents: [])
    let _state = ManagedAtomic<GatewayState>(.noConnection)
    /// This `nonisolated var state` is just for protocol conformance
    public nonisolated var state: GatewayState {
        self._state.load(ordering: .relaxed)
    }
    var eventContinuations = [AsyncStream<Gateway.Event>.Continuation]()
    
    public init() { }
    
    public func connect() async {
        self._state.store(.connected, ordering: .relaxed)
        self.connectionWaiter?.resume()
        self.connectionWaiter = nil
    }

    public func requestGuildMembersChunk(payload: Gateway.RequestGuildMembers) async { }
    public func updatePresence(payload: Gateway.Identify.Presence) async { }
    public func updateVoiceState(payload: VoiceStateUpdate) async { }
    public func makeEventsStream() async -> AsyncStream<Gateway.Event> {
        AsyncStream { continuation in
            eventContinuations.append(continuation)
        }
    }
    public func makeEventsParseFailureStream() async -> AsyncStream<(any Error, ByteBuffer)> {
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

public enum EventKey: String, Sendable {
    case thanksMessage
    case thanksMessage2
    case linkInteraction
    case thanksReaction
    case thanksReaction2
    case thanksReaction3
    case thanksReaction4
    case stopRespondingToMessages
    case autoPingsTrigger
    case autoPingsTrigger2
    case howManyCoins1
    case howManyCoins2
    case serverBoost
    
    /// The endpoints from which the bot will send a response, after receiving each event.
    public var responseEndpoints: [APIEndpoint] {
        switch self {
        case .thanksMessage:
            return [.createMessage(channelId: "519613337638797315")]
        case .thanksMessage2:
            return [.createMessage(channelId: Constants.Channels.thanks.id)]
        case .linkInteraction:
            return [.updateOriginalInteractionResponse(applicationId: "11111111", interactionToken: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw"), .createInteractionResponse(interactionId: "1031112113978089502", interactionToken: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw")]
        case .thanksReaction:
            return [.createMessage(channelId: "684159753189982218")]
        case .thanksReaction2:
            return [.updateMessage(
                channelId: "684159753189982218",
                messageId: "1031112115928449022"
            )]
        case .thanksReaction3:
            return [.createMessage(channelId: Constants.Channels.thanks.id)]
        case .thanksReaction4:
            return [.updateMessage(
                channelId: Constants.Channels.thanks.id,
                messageId: "1031112115928111022"
            )]
        case .stopRespondingToMessages:
            return [.createMessage(channelId: "1067060193982156880")]
        case .autoPingsTrigger, .autoPingsTrigger2:
            return [
                .createDm,
                .createMessage(channelId: "1018169583619821619")
            ]
        case .howManyCoins1:
            return [.updateOriginalInteractionResponse(applicationId: "11111111", interactionToken: "aW50ZXJhY3Rpb246MTA1OTM0NTUzNjM2NjQyMDExODowbHZldWtVOUVvMVFCMEhnSjR2RmJrMncyOXNuV3J6OVR5Qk9mZ2h6YzhMSDVTdEZ3NWNIMXA1VzJlZ2RteXdHbzFGdGl0dVFMa2dBNVZUUndmVVFqZzJhUDJlTERuNDRjYXBuSWRHZzRwSFZnNjJLR3hZM1hKNjRuaWtCUzZpeg"), .createInteractionResponse(interactionId: "1059345536366420118", interactionToken: "aW50ZXJhY3Rpb246MTA1OTM0NTUzNjM2NjQyMDExODowbHZldWtVOUVvMVFCMEhnSjR2RmJrMncyOXNuV3J6OVR5Qk9mZ2h6YzhMSDVTdEZ3NWNIMXA1VzJlZ2RteXdHbzFGdGl0dVFMa2dBNVZUUndmVVFqZzJhUDJlTERuNDRjYXBuSWRHZzRwSFZnNjJLR3hZM1hKNjRuaWtCUzZpeg")]
        case .howManyCoins2:
            return [.updateOriginalInteractionResponse(applicationId: "11111111", interactionToken: "aW50ZXJhY3Rpb246MTA1OTM0NTY0MTY1MTgzMDg1NTp2NWI1eVFkNEVJdHJaRlc0bUZoRmNjMUFKeHNqS09YcXhHTUxHZGJIMXdzdFhkVkhWSk95YnNUdUV4U29UdUl3ejJsN2k0RTlDNVA3Nmhza2xIdkdrR2ZQRnduOEFBNUFlM28zN1NzSlJta0tVSkt1M1FxQ1lvb3FZU1lnMWg1ag"), .createInteractionResponse(interactionId: "1059345641651830855", interactionToken: "aW50ZXJhY3Rpb246MTA1OTM0NTY0MTY1MTgzMDg1NTp2NWI1eVFkNEVJdHJaRlc0bUZoRmNjMUFKeHNqS09YcXhHTUxHZGJIMXdzdFhkVkhWSk95YnNUdUV4U29UdUl3ejJsN2k0RTlDNVA3Nmhza2xIdkdrR2ZQRnduOEFBNUFlM28zN1NzSlJta0tVSkt1M1FxQ1lvb3FZU1lnMWg1ag")]
        case .serverBoost:
            return [.createMessage(channelId: "443074453719744522")]
        }
    }
}
