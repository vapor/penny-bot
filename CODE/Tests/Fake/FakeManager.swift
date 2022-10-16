@testable import DiscordBM
@testable import PennyBOT
import AsyncHTTPClient
import Logging
import Foundation
import XCTest

private let testData: [String: Any] = {
    let fileManager = FileManager.default
    let currentDirectory = fileManager.currentDirectoryPath
    let path = currentDirectory + "/Tests/Resources/data.json"
    let data = fileManager.contents(atPath: path)!
    let object = try! JSONSerialization.jsonObject(with: data, options: [])
    return object as! [String: Any]
}()

/// Probably could be more efficient than encoding then decoding again?!
func testData(for key: String) -> Data? {
    if let object = testData[key] {
        return try! JSONSerialization.data(withJSONObject: object)
    } else {
        return nil
    }
}

public enum EventKey: String {
    case thanksMessage
    case linkInteraction
    case thanksReaction
}

public actor FakeManager: GatewayManager {
    public nonisolated let client: any DiscordClient = FakeDiscordClient()
    public nonisolated let id = 0
    public nonisolated let state: GatewayState = .connected
    
    public init() { }
    public static var shared = FakeManager()
    
    public nonisolated func connect() { }
    public func requestGuildMembersChunk(payload: Gateway.RequestGuildMembers) async { }
    public func addEventHandler(_ handler: @escaping (Gateway.Event) -> Void) async { }
    public func addEventParseFailureHandler(
        _ handler: @escaping (Error, String) -> Void
    ) async { }
    public nonisolated func disconnect() { }
    
    public func send(key: EventKey) {
        let data = testData(for: key.rawValue)!
        let decoder = JSONDecoder()
        let event = try! decoder.decode(Gateway.Event.self, from: data)
        EventHandler(
            event: event,
            discordClient: FakeDiscordClient(),
            coinService: FakeCoinService(),
            logger: Logger(label: "Test_EventHandler")
        ).handle()
    }
    
    public func sendAndAwaitResponse<T>(
        key: EventKey,
        endpoint: Endpoint,
        as type: T.Type = T.self,
        file: String = #file,
        line: UInt = #line
    ) async throws -> T {
        let value: Any = await withCheckedContinuation { cont in
            Task {
                continuations[endpoint.urlSuffix] = cont
                self.send(key: key)
                try await Task.sleep(nanoseconds: 3_000_000_000)
                if continuations.removeValue(forKey: endpoint.urlSuffix) != nil {
                    XCTFail("Penny did not respond in-time to \(endpoint.urlSuffix)")
                    cont.resume(with: .success(Optional<Never>.none as Any))
                }
            }
        }

        let unwrapped = try XCTUnwrap(
            value as? T,
            "Value \(value) can't be cast to \(_typeName(T.self))."
        )
        return unwrapped
    }
    
    private var continuations = [String: CheckedContinuation<Any, Never>]()
    
    fileprivate func respond(to endpoint: Endpoint, with payload: Any) {
        if let cont = continuations.removeValue(forKey: endpoint.urlSuffix) {
            cont.resume(returning: payload)
        }
    }
}

private struct FakeDiscordClient: DiscordClient {
    let appId: String? = "11111111"
    
    func send(
        to endpoint: Endpoint,
        queries: [(String, String?)]
    ) async throws -> DiscordHTTPResponse {
        // Notify the mocked manager that the app has responded
        // to the message by trying to send a message to Discord.
        await FakeManager.shared.respond(to: endpoint, with: "")
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: testData(for: endpoint.urlSuffix).map { .init(data: $0) }
        )
    }
    
    func send<E: Encodable>(
        to endpoint: Endpoint,
        queries: [(String, String?)],
        payload: E
    ) async throws -> DiscordHTTPResponse {
        // Notify the mocked manager that the app has responded
        // to the message by trying to send a message to Discord.
        await FakeManager.shared.respond(to: endpoint, with: payload)
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: testData(for: endpoint.urlSuffix).map { .init(data: $0) }
        )
    }
}
