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
    public func requestGuildMembersChunk(payload: Gateway.RequestGuildMembers) { }
    public func addEventHandler(_ handler: @escaping (Gateway.Event) -> Void) {
        eventHandlers.append(handler)
    }
    public func addEventParseFailureHandler(_ handler: @escaping (Error, String) -> Void) { }
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
        let value = await withCheckedContinuation {
            (continuation: CheckedContinuation<Any, Never>) in
            FakeResponseStorage.shared.expect(
                at: endpoint ?? key.responseEndpoints[0],
                continuation: continuation,
                file: file,
                line: line
            )
            self.send(key: key)
        }
        let unwrapped = try XCTUnwrap(
            value as? T,
            "Value '\(value)' can't be cast to '\(_typeName(T.self))'",
            file: file,
            line: line
        )
        return unwrapped
    }
}

public enum EventKey: String {
    case thanksMessage
    case linkInteraction
    case thanksReaction
    case thanksReaction2
    case stopRespondingToMessages
    case autoPingsTrigger
    case howManyCoins1
    case howManyCoins2
    
    /// The endpoints from which the bot will send a response, after receiving each event.
    public var responseEndpoints: [Endpoint] {
        switch self {
        case .thanksMessage:
            return [.createMessage(channelId: "1016614538398937098")]
        case .linkInteraction:
            return [.editInteractionResponse(appId: "11111111", token: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw"), .createInteractionResponse(id: "1031112113978089502", token: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw")]
        case .thanksReaction:
            return [.createMessage(channelId: "966722151359057911")]
        case .thanksReaction2:
            return [.editMessage(
                channelId: "966722151359057911",
                messageId: "1031112115928449022"
            )]
        case .stopRespondingToMessages:
            return [.createMessage(channelId: "441327731486097429")]
        case .autoPingsTrigger:
            return [
                .createDM,
                .createDM,
                .createMessage(channelId: "1018169583619821619"),
                .createMessage(channelId: "1018169583619821619")
            ]
        case .howManyCoins1:
            return [.editInteractionResponse(appId: "11111111", token: "aW50ZXJhY3Rpb246MTA1OTM0NTUzNjM2NjQyMDExODowbHZldWtVOUVvMVFCMEhnSjR2RmJrMncyOXNuV3J6OVR5Qk9mZ2h6YzhMSDVTdEZ3NWNIMXA1VzJlZ2RteXdHbzFGdGl0dVFMa2dBNVZUUndmVVFqZzJhUDJlTERuNDRjYXBuSWRHZzRwSFZnNjJLR3hZM1hKNjRuaWtCUzZpeg"), .createInteractionResponse(id: "1059345536366420118", token: "aW50ZXJhY3Rpb246MTA1OTM0NTUzNjM2NjQyMDExODowbHZldWtVOUVvMVFCMEhnSjR2RmJrMncyOXNuV3J6OVR5Qk9mZ2h6YzhMSDVTdEZ3NWNIMXA1VzJlZ2RteXdHbzFGdGl0dVFMa2dBNVZUUndmVVFqZzJhUDJlTERuNDRjYXBuSWRHZzRwSFZnNjJLR3hZM1hKNjRuaWtCUzZpeg")]
        case .howManyCoins2:
            return [.editInteractionResponse(appId: "11111111", token: "aW50ZXJhY3Rpb246MTA1OTM0NTY0MTY1MTgzMDg1NTp2NWI1eVFkNEVJdHJaRlc0bUZoRmNjMUFKeHNqS09YcXhHTUxHZGJIMXdzdFhkVkhWSk95YnNUdUV4U29UdUl3ejJsN2k0RTlDNVA3Nmhza2xIdkdrR2ZQRnduOEFBNUFlM28zN1NzSlJta0tVSkt1M1FxQ1lvb3FZU1lnMWg1ag"), .createInteractionResponse(id: "1059345641651830855", token: "aW50ZXJhY3Rpb246MTA1OTM0NTY0MTY1MTgzMDg1NTp2NWI1eVFkNEVJdHJaRlc0bUZoRmNjMUFKeHNqS09YcXhHTUxHZGJIMXdzdFhkVkhWSk95YnNUdUV4U29UdUl3ejJsN2k0RTlDNVA3Nmhza2xIdkdrR2ZQRnduOEFBNUFlM28zN1NzSlJta0tVSkt1M1FxQ1lvb3FZU1lnMWg1ag")]
        }
    }
}
