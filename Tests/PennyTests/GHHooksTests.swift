@testable import GHHooksLambda
import SotoCore
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

    func testUnicodesPrefix() throws {
        let dots = "..." /// 3 scalars

        do {
            let scalars_16 = "Hello, world! 👍🏾"
            let scalars_12 = "Hello, world"
            let scalars_11 = "Hello, worl"
            let scalars_10 = "Hello, wor"
            let scalars_9 = "Hello, wo"
            let scalars_4 = "Hell"
            XCTAssertEqual(scalars_16.unicodesPrefix(17), scalars_16)
            XCTAssertEqual(scalars_16.unicodesPrefix(16), scalars_16)
            XCTAssertEqual(scalars_16.unicodesPrefix(15), scalars_12 + dots)
            XCTAssertEqual(scalars_16.unicodesPrefix(14), scalars_11 + dots)
            XCTAssertEqual(scalars_16.unicodesPrefix(13), scalars_10 + dots)
            XCTAssertEqual(scalars_16.unicodesPrefix(12), scalars_9 + dots)
            XCTAssertEqual(scalars_16.unicodesPrefix(7), scalars_4 + dots)
        }

        do {
            let scalars_11 = "👍🏿👍🏾👍🏽👍🏼👍🏻👍"
            let scalars_6 = "👍🏿👍🏾👍🏽"
            let scalars_4 = "👍🏿👍🏾"
            let scalars_2 = "👍🏿"
            XCTAssertEqual(scalars_11.unicodesPrefix(12), scalars_11)
            XCTAssertEqual(scalars_11.unicodesPrefix(11), scalars_11)
            XCTAssertEqual(scalars_11.unicodesPrefix(10), scalars_6 + dots)
            XCTAssertEqual(scalars_11.unicodesPrefix(9), scalars_6 + dots)
            XCTAssertEqual(scalars_11.unicodesPrefix(8), scalars_4 + dots)
            XCTAssertEqual(scalars_11.unicodesPrefix(7), scalars_4 + dots)
            XCTAssertEqual(scalars_11.unicodesPrefix(6), scalars_2 + dots)
        }

        do {
            let scalars_14 = "👩‍👩‍👧‍👦👨‍👨‍👧‍👦"
            let scalars_7 = "👩‍👩‍👧‍👦"
            let scalars_0 = ""
            XCTAssertEqual(scalars_14.unicodesPrefix(15), scalars_14)
            XCTAssertEqual(scalars_14.unicodesPrefix(14), scalars_14)
            XCTAssertEqual(scalars_14.unicodesPrefix(13), scalars_7 + dots)
            XCTAssertEqual(scalars_14.unicodesPrefix(10), scalars_7 + dots)
            XCTAssertEqual(scalars_14.unicodesPrefix(9), scalars_0 + dots)
            XCTAssertEqual(scalars_14.unicodesPrefix(8), scalars_0 + dots)
            XCTAssertEqual(scalars_14.unicodesPrefix(7), scalars_0 + dots)
            XCTAssertEqual(scalars_14.unicodesPrefix(6), scalars_0 + dots)
            XCTAssertEqual(scalars_14.unicodesPrefix(3), scalars_0 + dots)
            XCTAssertEqual(scalars_14.unicodesPrefix(2), scalars_0)
            XCTAssertEqual(scalars_14.unicodesPrefix(1), scalars_0)
            XCTAssertEqual(scalars_14.unicodesPrefix(0), scalars_0)
        }
    }

    func testSemVerBump() throws {
        do {
            let version = try XCTUnwrap(SemanticVersion(string: "11.0.0"))
            let next = try XCTUnwrap(version.next(.major))
            XCTAssertEqual(next.description, "12.0.0")
        }

        do {
            let version = try XCTUnwrap(SemanticVersion(string: "2.12.0"))
            let next = try XCTUnwrap(version.next(.minor))
            XCTAssertEqual(next.description, "2.13.0")
        }

        do {
            let version = try XCTUnwrap(SemanticVersion(string: "0.0.299"))
            let next = try XCTUnwrap(version.next(.patch))
            XCTAssertEqual(next.description, "0.0.300")
        }

        do {
            let version = try XCTUnwrap(SemanticVersion(string: "122.9.67-alpha.1"))
            let next = try XCTUnwrap(version.next(.major))
            XCTAssertEqual(next.description, "122.9.67-alpha.2")
        }

        do {
            let version = try XCTUnwrap(SemanticVersion(string: "122.9.67-alpha"))
            let next = try XCTUnwrap(version.next(.major))
            XCTAssertEqual(next.description, "122.9.67-alpha.1")
        }

        do {
            let version = try XCTUnwrap(SemanticVersion(string: "122.9.67-alpha.44.55"))
            let next = try XCTUnwrap(version.next(.minor))
            XCTAssertEqual(next.description, "122.9.67-alpha.44.56")
        }

        do {
            let version = try XCTUnwrap(SemanticVersion(string: "122.9.67-alpha"))
            let next = try XCTUnwrap(version.next(.minor))
            XCTAssertEqual(next.description, "122.9.67-alpha.0.1")
        }

        do {
            let version = try XCTUnwrap(SemanticVersion(string: "122.9.67-alpha.1"))
            let next = try XCTUnwrap(version.next(.minor))
            XCTAssertEqual(next.description, "122.9.67-alpha.1.1")
        }
    }

    func testEventHandler() async throws {
        try await handleEvent(key: "issue1", eventName: .issues, expect: .noResponse)
        try await handleEvent(
            key: "issue2",
            eventName: .issues,
            expect: .response(at: .issueAndPRs)
        )
        try await handleEvent(key: "issue3", eventName: .issues, expect: .noResponse)

        try await handleEvent(key: "pr1", eventName: .pull_request, expect: .noResponse)
        try await handleEvent(key: "pr2", eventName: .pull_request, expect: .noResponse)
        try await handleEvent(key: "pr3", eventName: .pull_request, expect: .noResponse)
        try await handleEvent(
            key: "pr4",
            eventName: .pull_request,
            expect: .response(at: .release)
        )
        try await handleEvent(
            key: "pr5",
            eventName: .pull_request,
            expect: .response(at: .release)
        )
        try await handleEvent(
            key: "pr6",
            eventName: .pull_request,
            expect: .noResponse
        )

        /// For now expect an error since there are no test values for
        /// the discord list-messages endpoint.
        try await handleEvent(
            key: "pr7",
            eventName: .pull_request,
            expect: .error(description: "DiscordHTTPError.emptyBody(DiscordHTTPResponse(host: discord.com, status: 200 OK, version: HTTP/2.0, headers: [], body: nil))")
        )
    }

    func handleEvent(
        key: String,
        eventName: GHEvent.Kind,
        expect: Expectation,
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
            if case let .response(channel, responseType) = expect {
                switch responseType {
                case .create:
                    let response = await FakeResponseStorage.shared.awaitResponse(
                        at: .createMessage(channelId: channel.id),
                        line: line
                    ).value
                    XCTAssertEqual(
                        "\(type(of: response))", "\(Payloads.CreateMessage.self)",
                        line: line
                    )
                case let .edit(messageId):
                    let response = await FakeResponseStorage.shared.awaitResponse(
                        at: .updateMessage(channelId: channel.id, messageId: messageId),
                        line: line
                    ).value
                    XCTAssertEqual(
                        "\(type(of: response))", "\(Payloads.EditMessage.self)",
                        line: line
                    )
                }
            }
        } catch {
            if case let .error(description) = expect,
               description == "\(error)" {
                /// Expected error
                return
            }

            let prettyJSON = try! JSONSerialization.data(
                withJSONObject: JSONSerialization.jsonObject(with: data),
                options: .prettyPrinted
            )
            let event = String(decoding: prettyJSON, as: UTF8.self)
            XCTFail(
                """
                Failed handling event.
                Error: \(error).
                Event name: \(eventName).
                Event: \(event).
                """,
                line: line
            )
        }
    }

    enum Expectation {
        enum ResponseKind {
            case create
            case edit(messageId: MessageSnowflake)
        }

        case noResponse
        case response(at: Constants.Channels, type: ResponseKind = .create)
        case error(description: String)
    }
}
