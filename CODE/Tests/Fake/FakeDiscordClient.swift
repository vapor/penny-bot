@testable import DiscordBM
import NIOHTTP1

struct FakeDiscordClient: DiscordClient {
    let appId: String? = "11111111"
    
    func send(request: DiscordHTTPRequest) async throws -> DiscordHTTPResponse {
        await FakeResponseStorage.shared.respond(
            to: request.endpoint,
            with: Optional<Never>.none as Any
        )
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: request.endpoint.testingKey).map { .init(data: $0) }
        )
    }
    
    func send<E: Encodable>(
        request: DiscordHTTPRequest,
        payload: E
    ) async throws -> DiscordHTTPResponse {
        await FakeResponseStorage.shared.respond(to: request.endpoint, with: payload)
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: request.endpoint.testingKey).map { .init(data: $0) }
        )
    }
    
    func sendMultipart<E: MultipartEncodable>(
        request: DiscordHTTPRequest,
        payload: E
    ) async throws -> DiscordHTTPResponse {
        await FakeResponseStorage.shared.respond(to: request.endpoint, with: payload)
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: request.endpoint.testingKey).map { .init(data: $0) }
        )
    }
}
