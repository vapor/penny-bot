@testable import DiscordBM
import NIOHTTP1
import XCTest

struct FakeDiscordClient: DiscordClient {
    var appId: ApplicationSnowflake? = "11111111"
    
    func send(request: DiscordHTTPRequest) async throws -> DiscordHTTPResponse {
        await FakeResponseStorage.shared.respond(
            to: request.endpoint,
            with: AnyBox(Optional<Never>.none as Any)
        )
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: request.endpoint.testingKey).map { .init(data: $0) }
        )
    }
    
    func send<E: Encodable & ValidatablePayload>(
        request: DiscordHTTPRequest,
        payload: E
    ) async throws -> DiscordHTTPResponse {
        /// Catches invalid payloads in tests, instead of in production.
        /// Useful for validating for example the application/slash commands.
        XCTAssertNoThrow(try payload.validate().throw(model: payload))

        await FakeResponseStorage.shared.respond(to: request.endpoint, with: AnyBox(payload))
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: request.endpoint.testingKey).map { .init(data: $0) }
        )
    }
    
    func sendMultipart<E: MultipartEncodable & ValidatablePayload>(
        request: DiscordHTTPRequest,
        payload: E
    ) async throws -> DiscordHTTPResponse {
        /// Catches invalid payloads in tests, instead of in production.
        /// Useful for validating for example the application/slash commands.
        XCTAssertNoThrow(try payload.validate().throw(model: payload))

        await FakeResponseStorage.shared.respond(to: request.endpoint, with: AnyBox(payload))

        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: TestData.for(key: request.endpoint.testingKey).map { .init(data: $0) }
        )
    }
}
