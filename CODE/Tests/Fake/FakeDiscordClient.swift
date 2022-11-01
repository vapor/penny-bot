@testable import DiscordBM

struct FakeDiscordClient: DiscordClient {
    let appId: String? = "11111111"
    
    func send(
        to endpoint: Endpoint,
        queries: [(String, String?)]
    ) async throws -> DiscordHTTPResponse {
        // Notify the mocked manager that the app has responded
        // to the message by trying to send a message to Discord.
        await FakeResponseStorage.shared.respond(
            to: endpoint,
            with: Optional<Never>.none as Any
        )
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: endpoint.urlSuffix).map { .init(data: $0) }
        )
    }
    
    func send<E: Encodable>(
        to endpoint: Endpoint,
        queries: [(String, String?)],
        payload: E
    ) async throws -> DiscordHTTPResponse {
        // Notify the mocked manager that the app has responded
        // to the message by trying to send a message to Discord.
        await FakeResponseStorage.shared.respond(to: endpoint, with: payload)
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: endpoint.urlSuffix).map { .init(data: $0) }
        )
    }
}
