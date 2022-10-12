import DiscordBM
import AsyncHTTPClient

actor MockedManager: GatewayManager {
    nonisolated let client: any DiscordClient = MockedDiscordClient()
    nonisolated let id = 0
    nonisolated let state: GatewayState = .connected
    var eventHandlers: [(Gateway.Event) -> Void] = []
    
    private init() { }
    static let shared = MockedManager()
    
    nonisolated func connect() { }
    func requestGuildMembersChunk(payload: Gateway.RequestGuildMembers) async { }
    func addEventHandler(_ handler: @escaping (Gateway.Event) -> Void) async {
        eventHandlers.append(handler)
    }
    func addEventParseFailureHandler(_ handler: @escaping (Error, String) -> Void) async { }
    nonisolated func disconnect() { }
    
    func send(event: Gateway.Event) {
        for handler in eventHandlers {
            handler(event)
        }
    }
}

private struct MockedDiscordClient: DiscordClient {
    var appId: String? = "mocked"
    
    init() { }
    
    func send(
        to endpoint: Endpoint,
        queries: [(String, String?)]
    ) async throws -> DiscordHTTPResponse {
        DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: nil
        )
    }
    
    func send<E: Encodable>(
        to endpoint: Endpoint,
        queries: [(String, String?)],
        payload: E
    ) async throws -> DiscordHTTPResponse {
        DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: nil
        )
    }
}
