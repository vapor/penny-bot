@testable import GHHooksLambda
import DiscordModels
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
        try await handleEvent(key: "issue1", eventName: .issues, expectNoResponse: true)
        try await handleEvent(key: "issue2", eventName: .issues, expectNoResponse: false)
        try await handleEvent(key: "issue3", eventName: .issues, expectNoResponse: true)

        try await handleEvent(key: "pr1", eventName: .pull_request, expectNoResponse: true)
        try await handleEvent(key: "pr2", eventName: .pull_request, expectNoResponse: true)
        try await handleEvent(key: "pr3", eventName: .pull_request, expectNoResponse: true)
        try await handleEvent(key: "pr5", eventName: .pull_request, expectNoResponse: true)
    }

    func handleEvent(
        key: String,
        eventName: GHEvent.Kind,
        expectNoResponse: Bool,
        line: UInt = #line
    ) async throws {
        let data = TestData.for(ghEventKey: key)!
        do {
            let event = try decoder.decode(GHEvent.self, from: data)
            try await EventHandler(
                client: FakeDiscordClient(),
                eventName: eventName,
                event: event
            ).handle()
            let response = await FakeResponseStorage.shared.awaitResponse(
                at: .createMessage(channelId: Constants.Channels.issueAndPRs.id),
                expectFailure: expectNoResponse,
                line: line
            ).value
            if !expectNoResponse {
                XCTAssertNotNil(response as? Payloads.CreateMessage, line: line)
            }
        } catch {
            let prettyJSON = try? JSONSerialization.data(
                withJSONObject: JSONSerialization.jsonObject(with: data),
                options: .prettyPrinted
            )
            let event = prettyJSON.map({ String(decoding: $0, as: UTF8.self) })!
            XCTFail("Failed handling event with error: \(error). EventName: \(eventName), event: \(event)", line: line)
        }
    }
}
