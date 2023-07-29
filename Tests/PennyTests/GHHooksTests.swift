@testable import GHHooksLambda
import AsyncHTTPClient
import GitHubAPI
import SotoCore
import DiscordModels
import OpenAPIRuntime
import Rendering
import Logging
import SwiftSemver
import Markdown
import Fake
import XCTest

class GHHooksTests: XCTestCase {
    let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
    let decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    override func setUp() async throws {
        FakeResponseStorage.shared = FakeResponseStorage()
    }

    override func tearDown() {
        try! httpClient.syncShutdown()
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

    func testMarkdownFormatting() async throws {
        /// Remove html and images + length limits.
        do {
            let scalars_206 = "Add new, fully source-compatible APIs to `JWTSigners` and `JWTSigner` which allow specifying custom `JSONEncoder` and `JSONDecoder` instances. (The ability to use non-Foundation JSON coders is not included)"
            let text = """
            <!-- 🚀 Thank you for contributing! -->

            ![test image](https://github.com/vapor/something/9j13e91j3e9j03jr0j230dm02)

            <!-- Describe your changes clearly and use examples if possible -->

            \(scalars_206)

            <img width="1273" alt="Vapor_docs_dark" src="https://github.com/vapor/docs/assets/54376466/109dbef2-a090-49ef-9db7-9952dd848e13">

            Custom coders specified for a single `JWTSigner` affect token parsing and signing performed only by that signer. Custom coders specified on a `JWTSigners` object will become the default coders for all signers added to that object, unless a given signer already specifies its own custom coders.
            """

            let formatted = text.formatMarkdown(maxLength: 256, trailingParagraphMinLength: 64)
            XCTAssertEqual(formatted, scalars_206)
        }

        /// Remove html and images + length limits.
        do {
            let scalars_190 = "Add new, fully source-compatible APIs to `JWTSigners` and `JWTSigner` which allow specifying custom `JSONEncoder` and `JSONDecoder` instances. (The ability to use non-Foundation JSON coders)"
            let text = """
            <!-- 🚀 Thank you for contributing! -->

            ![test image](https://github.com/vapor/something/9j13e91j3e9j03jr0j230dm02)

            <!-- Describe your changes clearly and use examples if possible -->

            \(scalars_190)

            <img width="1273" alt="Vapor_docs_dark" src="https://github.com/vapor/docs/assets/54376466/109dbef2-a090-49ef-9db7-9952dd848e13">

            Custom coders specified for a single `JWTSigner` affect token parsing and signing performed only by that signer. Custom coders specified on a `JWTSigners` object will become the default coders for all signers added to that object, unless a given signer already specifies its own custom coders.
            """

            let formatted = text.formatMarkdown(maxLength: 256, trailingParagraphMinLength: 64)
            XCTAssertEqual(formatted, scalars_190 + """


            Custom coders specified for a single `JWTSigner` affect token…
            """)
        }

        /// Remove html and images + length limits.
        do {
            let scalars_aLot = "Add new, fully source-compatible APIs to `JWTSigners` and `JWTSigner` which allow specifying custom `JSONEncoder` and `JSONDecoder` instances. (The ability to use non-Foundation JSON coders) Custom coders specified for a single `JWTSigner` affect token parsing and signing performed only by that signer. Custom coders specified"
            let text = """
            <!-- 🚀 Thank you for contributing! -->

            ![test image](https://github.com/vapor/something/9j13e91j3e9j03jr0j230dm02)

            <!-- Describe your changes clearly and use examples if possible -->

            \(scalars_aLot)

            <img width="1273" alt="Vapor_docs_dark" src="https://github.com/vapor/docs/assets/54376466/109dbef2-a090-49ef-9db7-9952dd848e13">

            on a `JWTSigners` object will become the default coders for all signers added to that object, unless a given signer already specifies its own custom coders.
            """

            let formatted = text.formatMarkdown(maxLength: 256, trailingParagraphMinLength: 64)
            XCTAssertEqual(formatted, "Add new, fully source-compatible APIs to `JWTSigners` and `JWTSigner` which allow specifying custom `JSONEncoder` and `JSONDecoder` instances. (The ability to use non-Foundation JSON coders) Custom coders specified for a single `JWTSigner` affect token ...")
        }

        /// Remove empty links
        do {
            let text = """
            Bumps [sass](https://github.com/sass/dart-sass) from 1.63.6 to 1.64.0.
            
            [![Dependabot compatibility score](https://dependabot-badges.githubapp.com/badges/compatibility_score?dependency-name=sass&package-manager=npm_and_yarn&previous-version=1.63.6&new-version=1.64.0)](https://docs.github.com/en/github/managing-security-vulnerabilities/about-dependabot-security-updates#about-compatibility-scores)

            Dependabot will resolve any conflicts with this PR as long as you don't alter it yourself. You can also trigger a rebase manually by commenting `@dependabot rebase`.

            [//]: # (dependabot-automerge-start)
            [//]: # (dependabot-automerge-end)

            ---

            <details>
            <summary>Dependabot commands and options</summary>
            <br />

            You can trigger Dependabot actions by commenting on this PR:
            """

            let formatted = text.formatMarkdown(maxLength: 256, trailingParagraphMinLength: 128)
            XCTAssertEqual(formatted, """
            Bumps [sass](https://github.com/sass/dart-sass) from 1.63.6 to 1.64.0.

            Dependabot will resolve any conflicts with this PR as long as you don’t alter it yourself. You can also trigger a rebase manually by commenting `@dependabot rebase`.
            """)
        }
    }

    func testParseCodeOwners() async throws {
        let text = """
        # This is a comment.
        # Each line is a file pattern followed by one or more owners.

        # These owners will be the default owners for everything in
        *       @global-owner1 @global-owner2

        *.js    @js-owner #This is an inline comment.

        *.go docs@example.com

        *.txt @octo-org/octocats
        /build/logs/ @doctocat

        # The `docs/*` pattern will match files like
        # `docs/getting-started.md` but not further nested files like
        # `docs/build-app/troubleshooting.md`.
        docs/*  docs@example.com

        apps/ @octocat
        /docs/ @doctocat
        /scripts/ @doctocat @octocat
        **/logs @octocat

        /apps/ @octocat
        /apps/github
        """
        let context = try makeContext(
            eventName: .pull_request,
            eventKey: "pr1"
        )
        let handler = try ReleaseMaker(
            context: context,
            pr: context.event.pull_request!,
            number: context.event.number!
        )
        XCTAssertEqual(
            handler.context.parseCodeOwners(text: text).sorted(),
            ["docs@example.com", "doctocat", "global-owner1", "global-owner2", "js-owner", "octo-org/octocats", "octocat"]
        )
    }

    func testMakeReleaseBody() async throws {
        let context = try makeContext(
            eventName: .pull_request,
            eventKey: "pr4"
        )
        let handler = try ReleaseMaker(
            context: context,
            pr: context.event.pull_request!,
            number: context.event.number!
        )
        let body = try await handler.makeReleaseBody(
            mergedBy: context.event.pull_request!.merged_by!,
            previousVersion: "v2.3.1",
            newVersion: "v2.4.5"
        )
        XCTAssertTrue(body.hasPrefix("## What's Changed"), body)
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

        try await handleEvent(
            key: "pr8",
            eventName: .pull_request,
            expect: .noResponse
        )
        try await handleEvent(
            key: "pr9",
            eventName: .pull_request,
            expect: .noResponse
        )
        try await handleEvent(
            key: "pr10",
            eventName: .pull_request,
            expect: .noResponse
        )
        try await handleEvent(
            key: "pr11",
            eventName: .pull_request,
            expect: .noResponse
        )
        /// From `dependabot[bot]` so should be ignored
        try await handleEvent(
            key: "pr12",
            eventName: .pull_request,
            expect: .noResponse
        )
        try await handleEvent(
            key: "pr13",
            eventName: .pull_request,
            expect: .response(at: .issueAndPRs, type: .create)
        )


        try await handleEvent(
            key: "projects_v2_item1",
            eventName: .projects_v2_item,
            expect: .noResponse
        )

        try await handleEvent(
            key: "installation_repos1",
            eventName: .installation_repositories,
            expect: .noResponse
        )

        try await handleEvent(
            key: "push1",
            eventName: .push,
            expect: .noResponse
        )
        // TODO: Should assert that `create_issue` endpoint is called after this.
        try await handleEvent(
            key: "push2",
            eventName: .push,
            expect: .noResponse
        )

        try await handleEvent(
            key: "release1",
            eventName: .release,
            expect: .noResponse
        )
        try await handleEvent(
            key: "release2",
            eventName: .release,
            expect: .noResponse
        )
        try await handleEvent(
            key: "release3",
            eventName: .release,
            expect: .noResponse
        )
        try await handleEvent(
            key: "release4",
            eventName: .release,
            expect: .noResponse
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
                context: makeContext(
                    eventName: eventName,
                    event: event
                )
            ).handle()
            switch expect {
            case let .response(channel, responseType):
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
            case let .failure(channel, responseType):
                switch responseType {
                case .create:
                    let response = await FakeResponseStorage.shared.awaitResponse(
                        at: .createMessage(channelId: channel.id),
                        expectFailure: true,
                        line: line
                    ).value
                    XCTAssertEqual(
                        "\(type(of: response))", "Optional<Never>",
                        line: line
                    )
                case let .edit(messageID):
                    let response = await FakeResponseStorage.shared.awaitResponse(
                        at: .updateMessage(channelId: channel.id, messageId: messageID),
                        expectFailure: true,
                        line: line
                    ).value
                    XCTAssertEqual(
                        "\(type(of: response))", "Optional<Never>",
                        line: line
                    )
                }
            case .error:
                break
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

    func makeContext(eventName: GHEvent.Kind, eventKey: String) throws -> HandlerContext {
        let data = TestData.for(ghEventKey: eventKey)!
        let event = try decoder.decode(GHEvent.self, from: data)
        return try makeContext(
            eventName: eventName,
            event: event
        )
    }

    func makeContext(eventName: GHEvent.Kind, event: GHEvent) throws -> HandlerContext {
        let logger = Logger(label: "GHHooksTests")
        return HandlerContext(
            eventName: eventName,
            event: event,
            httpClient: httpClient,
            discordClient: FakeDiscordClient(),
            githubClient: Client(
                serverURL: try Servers.server1(),
                transport: FakeClientTransport()
            ),
            renderClient: RenderClient(
                renderer: try .forGHHooks(
                    httpClient: httpClient,
                    logger: logger
                )
            ),
            messageLookupRepo: FakeMessageLookupRepo(),
            usersService: FakeUsersService(),
            logger: logger
        )
    }

    enum Expectation {

        enum ResponseKind {
            case create
            case edit(messageId: MessageSnowflake)
        }

        case response(at: Constants.Channels, type: ResponseKind = .create)
        case failure(at: Constants.Channels, type: ResponseKind = .create)
        case error(description: String)

        static var noResponse: Self {
            .failure(at: .issueAndPRs)
        }
    }

    func XCTAssertThrowsErrorAsync(
        _ block: () async throws -> Void,
        line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("Did not throw error", line: line)
        } catch {
            /// Good
        }
    }
}
