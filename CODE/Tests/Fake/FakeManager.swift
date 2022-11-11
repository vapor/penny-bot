import DiscordBM
import Atomics
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
    public func addEventHandler(_ handler: @escaping (Gateway.Event) -> Void) async {
        eventHandlers.append(handler)
    }
    public func addEventParseFailureHandler(
        _ handler: @escaping (Error, String) -> Void
    ) async { }
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
    
    public func send(key: EventKey) throws {
        let data = TestData.for(key: key.rawValue)!
        let decoder = JSONDecoder()
        let event = try decoder.decode(Gateway.Event.self, from: data)
        for handler in eventHandlers {
            handler(event)
        }
    }
    
    public func sendAndAwaitResponse<T>(
        key: EventKey,
        as type: T.Type = T.self,
        file: String = #file,
        line: UInt = #line
    ) async throws -> T {
        try self.send(key: key)
        let value = await FakeResponseStorage.shared.awaitResponse(at: key.responseEndpoints[0])
        let unwrapped = try XCTUnwrap(
            value as? T,
            "Value '\(value)' can't be cast to '\(_typeName(T.self))'"
        )
        return unwrapped
    }
}

public enum EventKey: String {
    case thanksMessage
    case linkInteraction
    case thanksReaction
    case stopRespondingToMessages
    case autoPingsTrigger
    
    /// The endpoints from which the bot will send a response, after receiving each event.
    public var responseEndpoints: [Endpoint] {
        switch self {
        case .thanksMessage:
            return [.createMessage(channelId: "1016614538398937098")]
        case .linkInteraction:
            return [.editInteractionResponse(appId: "11111111", token: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw"), .createInteractionResponse(id: "1031112113978089502", token: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw")]
        case .thanksReaction:
            return [.createMessage(channelId: "966722151359057950")]
        case .stopRespondingToMessages:
            return [.createMessage(channelId: "441327731486097429")]
        case .autoPingsTrigger:
            return [
                .createDM,
                .createDM,
                .createMessage(channelId: "1018169583619821619"),
                .createMessage(channelId: "1018169583619821619")
            ]
        }
    }
}
