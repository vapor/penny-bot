import DiscordBM
@testable import PennyBOT
@preconcurrency import Atomics
import struct NIOCore.ByteBuffer
import XCTest

public actor FakeManager: GatewayManager {
    public nonisolated let client: any DiscordClient = FakeDiscordClient()
    public nonisolated let id = 0
    let _state = ManagedAtomic<GatewayState>(.noConnection)
    /// This `nonisolated var state` is just for protocol conformance
    public nonisolated var state: GatewayState {
        self._state.load(ordering: .relaxed)
    }
    var eventHandlers = [(Gateway.Event) -> Void]()
    
    public init() { }
    
    public func connect() {
        self._state.store(.connected, ordering: .relaxed)
        connectionWaiter?.resume()
    }

    public func requestGuildMembersChunk(payload: Gateway.RequestGuildMembers) async { }
    public func updatePresence(payload: Gateway.Identify.Presence) async { }
    public func updateVoiceState(payload: VoiceStateUpdate) async { }
    public func addEventHandler(_ handler: @Sendable @escaping (Gateway.Event) -> Void) async {
        eventHandlers.append(handler)
    }
    public func addEventParseFailureHandler(
        _ handler: @Sendable @escaping (Error, ByteBuffer) -> Void
    ) { }
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
        for handler in eventHandlers {
            handler(event)
        }
    }
    
    public func sendAndAwaitResponse<T>(
        key: EventKey,
        endpoint: Endpoint? = nil,
        as type: T.Type = T.self,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> T {
        let box = await withCheckedContinuation {
            (continuation: CheckedContinuation<AnyBox, Never>) in
            FakeResponseStorage.shared.expect(
                at: endpoint ?? key.responseEndpoints[0],
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
    
    /// The endpoints from which the bot will send a response, after receiving each event.
    public var responseEndpoints: [Endpoint] {
        switch self {
        case .thanksMessage:
            return [.createMessage(channelId: "519613337638797315")]
        case .thanksMessage2:
            return [.createMessage(channelId: Constants.thanksChannelId)]
        case .linkInteraction:
            return [.editInteractionResponse(appId: "11111111", token: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw"), .createInteractionResponse(id: "1031112113978089502", token: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw")]
        case .thanksReaction:
            return [.createMessage(channelId: "684159753189982218")]
        case .thanksReaction2:
            return [.editMessage(
                channelId: "684159753189982218",
                messageId: "1031112115928449022"
            )]
        case .thanksReaction3:
            return [.createMessage(channelId: Constants.thanksChannelId)]
        case .thanksReaction4:
            return [.editMessage(
                channelId: Constants.thanksChannelId,
                messageId: "1031112115928111022"
            )]
        case .stopRespondingToMessages:
            return [.createMessage(channelId: "1067060193982156880")]
        case .autoPingsTrigger, .autoPingsTrigger2:
            return [
                .createDM,
                .createMessage(channelId: "1018169583619821619")
            ]
        }
    }
}
