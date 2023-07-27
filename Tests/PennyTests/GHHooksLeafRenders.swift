@testable import GHHooksLambda
import AsyncHTTPClient
import GitHubAPI
import Fake
import XCTest

class GHHooksLeafRenders: XCTestCase, GHHooksTestCase {
    let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)

    override func setUp() async throws {
        FakeResponseStorage.shared = FakeResponseStorage()
    }

    override func tearDown() {
        try! httpClient.syncShutdown()
    }

    func testTranslationNeededTitle() async throws {
        let context = try makeContext(eventName: .push, eventKey: "push2")
        let rendered = try await context.renderClient.translationNeededTitle(number: 1)
        /// First test, assert if the string conversion stuff works at all.
        XCTAssertEqual(rendered, "Translation needed for 1")
    }

    func testTranslationNeededDescription() async throws {
        let context = try makeContext(eventName: .push, eventKey: "push2")
        let rendered = try await context.renderClient.translationNeededDescription(number: 1)
        XCTAssertGreaterThan(rendered.count, 5)
    }
}
