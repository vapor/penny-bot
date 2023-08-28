@testable import GHHooksLambda
import AsyncHTTPClient
import GitHubAPI
import SotoCore
import DiscordModels
import DiscordHTTP
import OpenAPIRuntime
import Rendering
import Logging
import SwiftSemver
import Markdown
import Fake
import XCTest

class GHHooksTests: XCTestCase {
    let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    let decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    /// The `…` (U+2026 Horizontal Ellipsis) character.
    let dots = "\u{2026}"

    override func setUp() async throws {
        FakeResponseStorage.shared = FakeResponseStorage()
    }

    override func tearDown() {
        try! httpClient.syncShutdown()
    }

    func testUnicodesPrefix() throws {
        do {
            let scalars_16 = "Hello, world! 👍🏾"
            let scalars_14 = "Hello, world! "
            let scalars_13 = "Hello, world!"
            let scalars_12 = "Hello, world"
            let scalars_11 = "Hello, worl"
            let scalars_6 = "Hello,"
            XCTAssertTuplesEqual(scalars_16.unicodesPrefix(17), (1, scalars_16))
            XCTAssertTuplesEqual(scalars_16.unicodesPrefix(16), (0, scalars_16))
            XCTAssertTuplesEqual(scalars_16.unicodesPrefix(15), (0, scalars_14 + dots))
            XCTAssertTuplesEqual(scalars_16.unicodesPrefix(14), (0, scalars_13 + dots))
            XCTAssertTuplesEqual(scalars_16.unicodesPrefix(13), (0, scalars_12 + dots))
            XCTAssertTuplesEqual(scalars_16.unicodesPrefix(12), (0, scalars_11 + dots))
            XCTAssertTuplesEqual(scalars_16.unicodesPrefix(7), (0, scalars_6 + dots))
        }

        do {
            let scalars_11 = "👍🏿👍🏾👍🏽👍🏼👍🏻👍"
            let scalars_8 = "👍🏿👍🏾👍🏽👍🏼"
            let scalars_6 = "👍🏿👍🏾👍🏽"
            let scalars_4 = "👍🏿👍🏾"
            let scalars_2 = "👍🏿"
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(12), (1, scalars_11))
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(11), (0, scalars_11))
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(10), (0, scalars_8 + dots))
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(9), (0, scalars_8 + dots))
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(8), (0, scalars_6 + dots))
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(7), (0, scalars_6 + dots))
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(6), (0, scalars_4 + dots))
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(4), (0, scalars_2 + dots))
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(3), (0, scalars_2 + dots))
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(2), (0, dots))
            XCTAssertTuplesEqual(scalars_11.unicodesPrefix(1), (0, dots))
        }

        do {
            let scalars_14 = "👩‍👩‍👧‍👦👨‍👨‍👧‍👦"
            let scalars_7 = "👩‍👩‍👧‍👦"
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(15), (1, scalars_14))
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(14), (0, scalars_14))
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(13), (0, scalars_7 + dots))
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(10), (0, scalars_7 + dots))
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(9), (0, scalars_7 + dots))
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(8), (0, scalars_7 + dots))
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(7), (0, dots))
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(6), (0, dots))
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(3), (0, dots))
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(2), (0, dots))
            XCTAssertTuplesEqual(scalars_14.unicodesPrefix(1), (0, dots))
        }
    }

    func testMarkdownUnicodesPrefix() async throws {
        do {
            let scalars_16 = "Hello, world! 👍🏾"
            let scalars_14 = "Hello, world! "
            let scalars_13 = "Hello, world!"
            let scalars_12 = "Hello, world"
            let scalars_11 = "Hello, worl"
            let scalars_6 = "Hello,"
            XCTAssertTuplesEqual(scalars_16.markdownUnicodesPrefix(17), (1, scalars_16))
            XCTAssertTuplesEqual(scalars_16.markdownUnicodesPrefix(16), (0, scalars_16))
            XCTAssertTuplesEqual(scalars_16.markdownUnicodesPrefix(15), (0, scalars_14 + dots))
            XCTAssertTuplesEqual(scalars_16.markdownUnicodesPrefix(14), (0, scalars_13 + dots))
            XCTAssertTuplesEqual(scalars_16.markdownUnicodesPrefix(13), (0, scalars_12 + dots))
            XCTAssertTuplesEqual(scalars_16.markdownUnicodesPrefix(12), (0, scalars_11 + dots))
            XCTAssertTuplesEqual(scalars_16.markdownUnicodesPrefix(7), (0, scalars_6 + dots))
        }

        do {
            let scalars_11 = "👍🏿👍🏾👍🏽👍🏼👍🏻👍"
            let scalars_8 = "👍🏿👍🏾👍🏽👍🏼"
            let scalars_6 = "👍🏿👍🏾👍🏽"
            let scalars_4 = "👍🏿👍🏾"
            let scalars_2 = "👍🏿"
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(12), (1, scalars_11))
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(11), (0, scalars_11))
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(10), (0, scalars_8 + dots))
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(9), (0, scalars_8 + dots))
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(8), (0, scalars_6 + dots))
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(7), (0, scalars_6 + dots))
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(6), (0, scalars_4 + dots))
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(4), (0, scalars_2 + dots))
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(3), (0, scalars_2 + dots))
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(2), (0, dots))
            XCTAssertTuplesEqual(scalars_11.markdownUnicodesPrefix(1), (0, dots))
        }

        do {
            let scalars_14 = "👩‍👩‍👧‍👦👨‍👨‍👧‍👦"
            let scalars_7 = "👩‍👩‍👧‍👦"
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(15), (1, scalars_14))
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(14), (0, scalars_14))
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(13), (0, scalars_7 + dots))
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(10), (0, scalars_7 + dots))
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(9), (0, scalars_7 + dots))
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(8), (0, scalars_7 + dots))
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(7), (0, dots))
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(6), (0, dots))
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(3), (0, dots))
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(2), (0, dots))
            XCTAssertTuplesEqual(scalars_14.markdownUnicodesPrefix(1), (0, dots))
        }

        /// Testing with markdown text
        do {
            let scalars_9 = "**Hello**"
            let scalars_8 = "**Hel\(dots)**"
            let scalars_7 = "**He\(dots)**"
            let scalars_6 = "**H\(dots)**"
            let scalars_5 = "**\(dots)**"
            XCTAssertEqual(scalars_9.markdownUnicodesPrefix(10), scalars_9)
            XCTAssertEqual(scalars_9.markdownUnicodesPrefix(9), scalars_9)
            XCTAssertEqual(scalars_9.markdownUnicodesPrefix(8), scalars_9)
            XCTAssertEqual(scalars_9.markdownUnicodesPrefix(7), scalars_9)
            XCTAssertEqual(scalars_9.markdownUnicodesPrefix(6), scalars_9)
            XCTAssertEqual(scalars_9.markdownUnicodesPrefix(5), scalars_9)
            XCTAssertEqual(scalars_9.markdownUnicodesPrefix(4), scalars_8)
            XCTAssertEqual(scalars_9.markdownUnicodesPrefix(3), scalars_7)
            XCTAssertEqual(scalars_9.markdownUnicodesPrefix(2), scalars_6)
            XCTAssertEqual(scalars_9.markdownUnicodesPrefix(1), scalars_5)
        }
    }

    func XCTAssertTuplesEqual(
        _ expression1: (Int, String),
        _ expression2: (Int, String),
        line: UInt = #line
    ) {
        XCTAssertEqual(expression1.0, expression2.0, line: line)
        XCTAssertEqual(expression1.1, expression2.1, line: line)
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
        do {
            let scalars_206 = "Add new, fully source-compatible APIs to `JWTSigners` and `JWTSigner` which allow specifying custom `JSONEncoder` and `JSONDecoder` instances. (The ability to use non-Foundation JSON coders is not included)"
            let formatted = scalars_206.formatMarkdown(
                maxVisualLength: 256,
                hardLimit: 2_048,
                trailingTextMinLength: 64
            )
            XCTAssertMultilineStringsEqual(formatted, scalars_206)
        }

        do {
            let scalars_206 = "Add new, fully source-compatible APIs to `JWTSigners` and `JWTSigner` which allow specifying custom `JSONEncoder` and `JSONDecoder` instances. (The ability to use non-Foundation JSON coders is not included)"
            let formatted = scalars_206.formatMarkdown(
                maxVisualLength: 200,
                hardLimit: 2_048,
                trailingTextMinLength: 64
            )
            XCTAssertMultilineStringsEqual(formatted, scalars_206)
        }

        do {
            let scalars_206 = "Add new, fully source-compatible APIs to `JWTSigners` and `JWTSigner` which allow specifying custom `JSONEncoder` and `JSONDecoder` instances. (The ability to use non-Foundation JSON coders is not included)"
            let formatted = scalars_206.formatMarkdown(
                maxVisualLength: 200,
                hardLimit: 203,
                trailingTextMinLength: 64
            )
            XCTAssertMultilineStringsEqual(formatted, """
            Add new, fully source-compatible APIs to `JWTSigners` and `JWTSigner` which allow specifying custom `JSONEncoder` and `JSONDecoder` instances. (The ability to use non-Foundation JSON coders is not inclu\(dots)
            """)
        }

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

            let formatted = text.formatMarkdown(
                maxVisualLength: 256,
                hardLimit: 2_048,
                trailingTextMinLength: 64
            )
            XCTAssertMultilineStringsEqual(formatted, scalars_206)
        }

        /// Remove html and images + length limits.
        do {
            let scalars_200 = "Add new, fully source-compatible APIs to `JWTSigners` and `JWTSigner` which allow specifying custom `JSONEncoder` and `JSONDecoder` instances. (The ability to use non-Foundation JSON coders is not int"
            let text = """
            <!-- 🚀 Thank you for contributing! -->

            ![test image](https://github.com/vapor/something/9j13e91j3e9j03jr0j230dm02)

            <!-- Describe your changes clearly and use examples if possible -->

            \(scalars_200)

            <img width="1273" alt="Vapor_docs_dark" src="https://github.com/vapor/docs/assets/54376466/109dbef2-a090-49ef-9db7-9952dd848e13">

            Custom coders specified for a single `JWTSigner` affect token parsing and signing performed only by that signer. Custom coders specified on a `JWTSigners` object will become the default coders for all signers added to that object, unless a given signer already specifies its own custom coders.
            """

            let formatted = text.formatMarkdown(
                maxVisualLength: 256,
                hardLimit: 2_048,
                trailingTextMinLength: 64
            )
            let scalars_66 = "Custom coders specified for a single `JWTSigner` affect token par…"
            XCTAssertMultilineStringsEqual(formatted, scalars_200 + """


            \(scalars_66)
            """)
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

            let formatted = text.formatMarkdown(
                maxVisualLength: 256,
                hardLimit: 2_048,
                trailingTextMinLength: 64
            )
            let scalars_76 = "Custom coders specified for a single `JWTSigner` affect token parsing and s…"
            XCTAssertMultilineStringsEqual(formatted, scalars_190 + """


            \(scalars_76)
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

            let formatted = text.formatMarkdown(
                maxVisualLength: 256,
                hardLimit: 2_048,
                trailingTextMinLength: 64
            )
            XCTAssertMultilineStringsEqual(formatted, "Add new, fully source-compatible APIs to `JWTSigners` and `JWTSigner` which allow specifying custom `JSONEncoder` and `JSONDecoder` instances. (The ability to use non-Foundation JSON coders) Custom coders specified for a single `JWTSigner` affect token parsing and …")
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

            let formatted = text.formatMarkdown(
                maxVisualLength: 256,
                hardLimit: 2_048,
                trailingTextMinLength: 96
            )
            XCTAssertMultilineStringsEqual(formatted, """
            Bumps [sass](https://github.com/sass/dart-sass) from 1.63.6 to 1.64.0.

            Dependabot will resolve any conflicts with this PR as long as you don’t alter it yourself. You can also trigger a rebase manually by commenting `@dependabot rebase`.
            """)
        }

        do {
            let text = """
            ### Describe the bug

            I've got a custom `Codable` type that throws an error when decoding... because it's being asked to decode an empty string, rather than being skipped because I've got `T?` rather than `T` as the type in my `Content`.

            ### To Reproduce

            1. Declare some custom `Codable` type that throws an error if told to decode from an empty string.
            2. Declare some custom `Content` struct that has an `Optional` of your custom type as a parameter.
            3. Have a browser submit a request that includes `yourThing: ` in the body. (Doable in Safari by creating an HTML form, giving it a date input with the right `name`, and then... not selecting a date before hitting submit)
            4. Observe thrown error.
            """

            let formatted = text.formatMarkdown(
                maxVisualLength: 256,
                hardLimit: 2_048,
                trailingTextMinLength: 96
            )
            // TODO: Handle this situation better os we don't end up with an empty list item.
            XCTAssertMultilineStringsEqual(formatted, """
            ### Describe the bug

            I’ve got a custom `Codable` type that throws an error when decoding… because it’s being asked to decode an empty string, rather than being skipped because I’ve got `T?` rather than `T` as the type in my `Content`.

            ### To Reproduce

            1. 
            """)
        }

        do {
            let text = """
            ### Describe the bug

            White text on white background is not readable.

            ### To Reproduce

            Go to [https://api.vapor.codes/fluent/documentation/fluent/](https://api.vapor.codes/fluent/documentation/fluent/)

            ### Expected behavior

            Expect some contrast between the text and the background.

            ### Environment

            * Vapor Framework version: current [https://api.vapor.codes/](https://api.vapor.codes/) website
            * Vapor Toolbox version: N/A
            * OS version: N/A
            """
            let formatted = text.formatMarkdown(
                maxVisualLength: 256,
                hardLimit: 2_048,
                trailingTextMinLength: 96
            )

            XCTAssertMultilineStringsEqual(formatted, """
            ### Describe the bug

            White text on white background is not readable.

            ### To Reproduce

            Go to <https://api.vapor.codes/fluent/documentation/fluent/>

            ### Expected behavior

            Expect some contrast between the text and the background.
            """)
        }
    }

    func testHeadingFinder() async throws {
        /// Goes into the `What's Changed` heading.
        let text = """
        ## What's Changed
        * Use HTTP Client from vapor and update APNS library, add multiple configs by @kylebrowning in https://github.com/vapor/apns/pull/46
        * Update package to use Alpha 5 by @kylebrowning in https://github.com/vapor/apns/pull/48
        * Add support for new version of APNSwift by @Gerzer in https://github.com/vapor/apns/pull/51
        * Update to latest APNS by @kylebrowning in https://github.com/vapor/apns/pull/52

        ## New Contributors
        * @Gerzer made their first contribution in https://github.com/vapor/apns/pull/51

        **Full Changelog**: https://github.com/vapor/apns/compare/3.0.0...4.0.0
        """

        let contentsOfHeading = try XCTUnwrap(text.contentsOfHeading(named: "What's Changed"))
        XCTAssertMultilineStringsEqual(contentsOfHeading, """
        - Use HTTP Client from vapor and update APNS library, add multiple configs by @kylebrowning in https://github.com/vapor/apns/pull/46
        - Update package to use Alpha 5 by @kylebrowning in https://github.com/vapor/apns/pull/48
        - Add support for new version of APNSwift by @Gerzer in https://github.com/vapor/apns/pull/51
        - Update to latest APNS by @kylebrowning in https://github.com/vapor/apns/pull/52
        """)
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
            handler.context.requester.parseCodeOwners(text: text).value.sorted(),
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
        try await handleEvent(key: "issue4", eventName: .issues, expect: .noResponse)
        /// Transferred issue.
        try await handleEvent(
            key: "issue5",
            eventName: .issues,
            expect: .response(
                at: .issueAndPRs,
                type: .edit(messageId: FakeMessageLookupRepo.randomMessageID)
            )
        )

        // TODO: Add real response-JSONs for project board stuff to `ghRestOperations.json`.

        /// Labeled with "help wanted"
        try await handleEvent(key: "issue6", eventName: .issues, expect: .noResponse)
        /// Unlabeled with "help wanted"
        try await handleEvent(key: "issue7", eventName: .issues, expect: .noResponse)

        try await handleEvent(key: "pr1", eventName: .pull_request, expect: .noResponse)
        try await handleEvent(key: "pr2", eventName: .pull_request, expect: .noResponse)
        try await handleEvent(key: "pr3", eventName: .pull_request, expect: .noResponse)
        try await handleEvent(
            key: "pr4",
            eventName: .pull_request,
            expect: .noResponse
        )
        try await handleEvent(
            key: "pr5",
            eventName: .pull_request,
            expect: .noResponse
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
            key: "push3",
            eventName: .push,
            expect: .noResponse
        )
        try await handleEvent(
            key: "push4",
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
            expect: .response(at: .release, type: .create)
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
        try await handleEvent(
            key: "release5",
            eventName: .release,
            expect: .response(at: .release, type: .create)
        )
        try await handleEvent(
            key: "release6",
            eventName: .release,
            expect: .response(at: .release, type: .create)
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
            case let .failure(failures):
                await withTaskGroup(of: Void.self) { group in
                    for failure in failures {
                        group.addTask {
                            let endpoint: APIEndpoint
                            switch failure.type {
                            case .create:
                                endpoint = .createMessage(channelId: failure.channel.id)
                            case let .edit(messageID):
                                endpoint = .updateMessage(
                                    channelId: failure.channel.id,
                                    messageId: messageID
                                )
                            }
                            let response = await FakeResponseStorage.shared.awaitResponse(
                                at: endpoint,
                                expectFailure: true,
                                line: line
                            ).value
                            XCTAssertEqual(
                                "\(type(of: response))", "Optional<Never>",
                                line: line
                            )
                        }
                    }
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

        struct Failure {
            let channel: GHHooksLambda.Constants.Channels
            let type: ResponseKind
        }

        case response(at: GHHooksLambda.Constants.Channels, type: ResponseKind = .create)
        case failure([Failure])
        case error(description: String)

        /// Checks for no responses in any of the channels.
        static var noResponse: Self {
            .failure(Constants.Channels.allCases.map({ .init(channel: $0, type: .create) }))
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
