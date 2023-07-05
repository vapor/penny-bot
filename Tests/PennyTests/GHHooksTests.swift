@testable import GHHooksLambda
import DiscordModels
import OpenAPIRuntime
import Logging
import SwiftSemver
import Fake
import XCTest

class GHHooksTests: XCTestCase {

    var decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    override func setUp() async throws {
        FakeResponseStorage.shared = FakeResponseStorage()
    }

    func testSemVerBump() throws {
        do {
            let version = SemanticVersion(string: "11.0.0")!
            let next = try XCTUnwrap(version.next(.major))
            XCTAssertEqual(next.description, "12.0.0")
        }

        do {
            let version = SemanticVersion(string: "2.12.0")!
            let next = try XCTUnwrap(version.next(.minor))
            XCTAssertEqual(next.description, "2.13.0")
        }

        do {
            let version = SemanticVersion(string: "0.0.299")!
            let next = try XCTUnwrap(version.next(.patch))
            XCTAssertEqual(next.description, "0.0.300")
        }

        do {
            let version = SemanticVersion(string: "122.9.67-alpha.1")!
            let next = try XCTUnwrap(version.next(.major))
            XCTAssertEqual(next.description, "122.9.67-alpha.2")
        }

        do {
            let version = SemanticVersion(string: "122.9.67-alpha")!
            let next = try XCTUnwrap(version.next(.major))
            XCTAssertEqual(next.description, "122.9.67-alpha.1")
        }

        do {
            let version = SemanticVersion(string: "122.9.67-alpha.44.55")!
            let next = try XCTUnwrap(version.next(.minor))
            XCTAssertEqual(next.description, "122.9.67-alpha.44.56")
        }

        do {
            let version = SemanticVersion(string: "122.9.67-alpha")!
            let next = try XCTUnwrap(version.next(.minor))
            XCTAssertEqual(next.description, "122.9.67-alpha.0.1")
        }

        do {
            let version = SemanticVersion(string: "122.9.67-alpha.1")!
            let next = try XCTUnwrap(version.next(.minor))
            XCTAssertEqual(next.description, "122.9.67-alpha.1.1")
        }
    }

    func testEventHandler() async throws {
        try await handleEvent(key: "issue1", eventName: .issues, expectResponse: false)
        try await handleEvent(key: "issue2", eventName: .issues, expectResponse: true)

        try await handleEvent(key: "pr1", eventName: .pull_request, expectResponse: false)
        try await handleEvent(key: "pr2", eventName: .pull_request, expectResponse: false)
        try await handleEvent(key: "pr3", eventName: .pull_request, expectResponse: false)
        try await handleEvent(
            key: "pr4",
            eventName: .pull_request,
            expectResponse: true,
            responseChannelId: Constants.Channels.logs.id
        )
    }

    func handleEvent(
        key: String,
        eventName: GHEvent.Kind,
        expectResponse: Bool,
        responseChannelId: ChannelSnowflake = Constants.Channels.issueAndPRs.id,
        line: UInt = #line
    ) async throws {
        let data = TestData.for(ghEventKey: key)!
        do {
            let event = try decoder.decode(GHEvent.self, from: data)
            try await EventHandler(
                context: .init(
                    eventName: eventName,
                    event: event,
                    discordClient: FakeDiscordClient(),
                    githubClient: Client(
                        serverURL: try Servers.server1(),
                        transport: FakeClientTransport()
                    ),
                    logger: Logger(label: "GHHooksTests")
                )
            ).handle()
            let response = await FakeResponseStorage.shared.awaitResponse(
                at: .createMessage(channelId: responseChannelId),
                expectFailure: !expectResponse,
                line: line
            ).value
            if expectResponse {
                XCTAssertTrue(
                    type(of: response) == Payloads.CreateMessage.self,
                    "'\(type(of: response))' is not equal to 'Payloads.CreateMessage'",
                    line: line
                )
            }
        } catch {
            let prettyJSON = try! JSONSerialization.data(
                withJSONObject: JSONSerialization.jsonObject(with: data),
                options: .prettyPrinted
            )
            let event = String(decoding: prettyJSON, as: UTF8.self)
            XCTFail("Failed handling event with error: \(error). EventName: \(eventName), event: \(event)", line: line)
        }
    }
}
