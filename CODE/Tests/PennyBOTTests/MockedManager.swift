@testable import DiscordBM
import AsyncHTTPClient
import Foundation

private let testData: [String: Any] = {
    let fileManager = FileManager.default
    let currentDirectory = fileManager.currentDirectoryPath
    let path = currentDirectory + "/Tests/Resources/data.json"
    let data = fileManager.contents(atPath: path)!
    let object = try! JSONSerialization.jsonObject(with: data, options: [])
    return object as! [String: Any]
}()

/// Probably could be more efficient than encoding then decoding again?!
func testData(for key: String) -> Data {
    try! JSONSerialization.data(
        withJSONObject: testData[key]!
    )
}

enum EventKey: String {
    case message_1
}

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
    
    func send(key: EventKey) {
        let data = testData(for: key.rawValue)
        let decoder = JSONDecoder()
        let event = try! decoder.decode(Gateway.Event.self, from: data)
        print("EVENT", event)
        for handler in eventHandlers {
            handler(event)
        }
    }
}

private struct MockedDiscordClient: DiscordClient {
    let appId: String? = "11111111"
    
    func send(
        to endpoint: Endpoint,
        queries: [(String, String?)]
    ) async throws -> DiscordHTTPResponse {
        DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: .init(data: testData(for: endpoint.urlSuffix))
        )
    }
    
    func send<E: Encodable>(
        to endpoint: Endpoint,
        queries: [(String, String?)],
        payload: E
    ) async throws -> DiscordHTTPResponse {
        let key: String?
        switch endpoint {
        case .createApplicationGlobalCommand: key = nil
        default: key = endpoint.urlSuffix
        }
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: key.map { .init(data: testData(for: $0) ) }
        )
    }
}
