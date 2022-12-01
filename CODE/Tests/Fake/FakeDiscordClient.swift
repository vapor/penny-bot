@testable import DiscordBM
import NIOHTTP1

struct FakeDiscordClient: DiscordClient {
    let appId: String? = "11111111"
    
    func send(
        to endpoint: Endpoint,
        queries: [(String, String?)],
        headers: HTTPHeaders
    ) async throws -> DiscordHTTPResponse {
        await FakeResponseStorage.shared.respond(
            to: endpoint,
            with: Optional<Never>.none as Any
        )
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: endpoint.testingKey).map { .init(data: $0) }
        )
    }
    
    func send<E: Encodable>(
        to endpoint: Endpoint,
        queries: [(String, String?)],
        headers: HTTPHeaders,
        payload: E
    ) async throws -> DiscordHTTPResponse {
        await FakeResponseStorage.shared.respond(to: endpoint, with: payload)
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: endpoint.testingKey).map { .init(data: $0) }
        )
    }
    
    func sendMultipart<E: MultipartEncodable>(
        to endpoint: Endpoint,
        queries: [(String, String?)],
        headers: HTTPHeaders,
        payload: E
    ) async throws -> DiscordHTTPResponse {
        await FakeResponseStorage.shared.respond(to: endpoint, with: payload)
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: endpoint.testingKey).map { .init(data: $0) }
        )
    }
}
