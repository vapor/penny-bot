@testable import GHHooksLambda
import AsyncHTTPClient
import GitHubAPI
import Logging
import Fake
import XCTest

class GHHooksLeafRenders: XCTestCase {
    let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
    lazy var renderClient = RenderClient(
        renderer: try! .forGHHooks(
            httpClient: httpClient,
            logger: Logger(label: "RenderClientGHHooksTests")
        )
    )

    override func setUp() async throws {
        FakeResponseStorage.shared = FakeResponseStorage()
    }

    override func tearDown() {
        try! httpClient.syncShutdown()
    }

    func testTranslationNeededTitle() async throws {
        let rendered = try await renderClient.translationNeededTitle(number: 1)
        /// First test, assert if the string conversion stuff works at all.
        XCTAssertEqual(rendered, "Translation needed for #1")
    }

    func testTranslationNeededDescription() async throws {
        let rendered = try await renderClient.translationNeededDescription(number: 1)
        XCTAssertGreaterThan(rendered.count, 5)
    }

    func testNewReleaseDescription() async throws {
        do {
            let rendered = try await renderClient.newReleaseDescription(
                context: .init(
                    pr: .init(
                        title: "PR title right here",
                        author: "0xTim",
                        number: 833
                    ),
                    isNewContributor: true,
                    reviewers: ["joannis", "vzsg"],
                    merged_by: "MahdiBM",
                    release: .init(
                        oldTag: "1.0.0",
                        newTag: "4.8.9"
                    )
                )
            )
            XCTAssertEqual(rendered, """
            ## What's Changed
            PR title right here by @0xTim in #833




            ## New Contributor
            - @0xTim made their first contribution 🎉 in #833




            ## Reviewers
            Thanks to the reviewers for their help:

            - @joannis

            - @vzsg




            ###### _This patch was released by @MahdiBM_

            **Full Changelog**: https://github.com//compare/1.0.0...4.8.9
            """)
        }

        do {
            let rendered = try await renderClient.newReleaseDescription(
                context: .init(
                    pr: .init(
                        title: "PR title right here",
                        author: "0xTim",
                        number: 833
                    ),
                    isNewContributor: false,
                    reviewers: [],
                    merged_by: "MahdiBM",
                    release: .init(
                        oldTag: "1.0.0",
                        newTag: "4.8.9"
                    )
                )
            )
            XCTAssertEqual(rendered, """
            ## What's Changed
            PR title right here by @0xTim in #833






            ## Reviewers
            Thanks to the reviewers for their help:




            ###### _This patch was released by @MahdiBM_

            **Full Changelog**: https://github.com//compare/1.0.0...4.8.9
            """)
        }
    }
}
