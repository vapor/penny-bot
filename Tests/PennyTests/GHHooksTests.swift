@testable import GHHooksLambda
import DiscordModels
import OpenAPIRuntime
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

    func testEventHandler() async throws {
        try await handleEvent(key: "issue1", eventName: .issues, expectResponse: false)
        try await handleEvent(key: "issue2", eventName: .issues, expectResponse: true)

        try await handleEvent(key: "pr1", eventName: .pull_request, expectResponse: false)
        try await handleEvent(key: "pr2", eventName: .pull_request, expectResponse: false)
        try await handleEvent(key: "pr3", eventName: .pull_request, expectResponse: false)
    }

    func handleEvent(
        key: String,
        eventName: GHEvent.Kind,
        expectResponse: Bool,
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
                    )
                )
            ).handle()
            let response = await FakeResponseStorage.shared.awaitResponse(
                at: .createMessage(channelId: Constants.Channels.issueAndPRs.id),
                expectFailure: !expectResponse,
                line: line
            ).value
            if expectResponse {
                XCTAssertNotNil(response as? Payloads.CreateMessage, line: line)
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
