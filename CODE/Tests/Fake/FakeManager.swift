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
    
    /// The endpoints from which the bot will send a response, after receiving each event.
    var responseEndpoints: [Endpoint] {
        switch self {
        case .thanksMessage:
            return [.postCreateMessage(channelId: "441327731486097429")]
        case .linkInteraction:
            return [.editOriginalInteractionResponse(appId: "11111111", token: "aW50ZXJhY3Rpb246MTAzMTExMjExMzk3ODA4OTUwMjpRVGVBVXU3Vk1XZ1R0QXpiYmhXbkpLcnFqN01MOXQ4T2pkcGRXYzRjUFNMZE9TQ3g4R3NyM1d3OGszalZGV2c3a0JJb2ZTZnluS3VlbUNBRDh5N2U3Rm00QzQ2SWRDMGJrelJtTFlveFI3S0RGbHBrZnpoWXJSNU1BV1RqYk5Xaw")]
        case .thanksReaction:
            return [.postCreateMessage(channelId: "966722151359057950")]
        }
    }
}

public actor FakeManager: GatewayManager {
    public nonisolated let client: any DiscordClient = FakeDiscordClient()
    public nonisolated let id = 0
    public nonisolated let state: GatewayState = .connected
    var eventHandlers = [(Gateway.Event) -> Void]()
    
    public init() { }
    
    public nonisolated func connect() { }
    public func requestGuildMembersChunk(payload: Gateway.RequestGuildMembers) async { }
    public func addEventHandler(_ handler: @escaping (Gateway.Event) -> Void) async {
        eventHandlers.append(handler)
    }
    public func addEventParseFailureHandler(
        _ handler: @escaping (Error, String) -> Void
    ) async { }
    public nonisolated func disconnect() { }
    
    public func send(key: EventKey) {
        let data = testData(for: key.rawValue)!
        let decoder = JSONDecoder()
        let event = try! decoder.decode(Gateway.Event.self, from: data)
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
        let value: Any = await withCheckedContinuation { continuation in
            Task {
                let endpoint = key.responseEndpoints.first!
                FakeResponseStorage.shared.expect(at: endpoint, continuation: continuation)
                self.send(key: key)
            }
        }
        
        let unwrapped = try XCTUnwrap(
            value as? T,
            "Value '\(value)' can't be cast to '\(_typeName(T.self))'"
        )
        return unwrapped
    }
}

public class FakeResponseStorage {
    
    private var continuations = [String: CheckedContinuation<Any, Never>]()
    private var unhandledResponses = [String: Any]()
    
    public init() { }
    public static var shared = FakeResponseStorage()
    
    public func awaitResponse(at endpoint: Endpoint) async -> Any {
        await withCheckedContinuation { continuation in
            self.expect(at: endpoint, continuation: continuation)
        }
    }
    
    func expect(at endpoint: Endpoint, continuation: CheckedContinuation<Any, Never>) {
        if let response = unhandledResponses[endpoint.urlSuffix] {
            continuation.resume(returning: response)
        } else {
            continuations[endpoint.urlSuffix] = continuation
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                if continuations.removeValue(forKey: endpoint.urlSuffix) != nil {
                    XCTFail("Penny did not respond in-time at '\(endpoint.urlSuffix)'")
                    continuation.resume(with: .success(Optional<Never>.none as Any))
                }
            }
        }
    }
    
    func respond(to endpoint: Endpoint, with payload: Any) {
        if let continuation = continuations.removeValue(forKey: endpoint.urlSuffix) {
            continuation.resume(returning: payload)
        } else {
            unhandledResponses[endpoint.urlSuffix] = payload
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
        FakeResponseStorage.shared.respond(to: endpoint, with: Optional<Never>.none as Any)
        
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
        FakeResponseStorage.shared.respond(to: endpoint, with: payload)
        
        return DiscordHTTPResponse(
            host: "discord.com",
            status: .ok,
            version: .http2,
            headers: [:],
            body: testData(for: endpoint.urlSuffix).map { .init(data: $0) }
        )
    }
}
