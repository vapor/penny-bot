import AsyncHTTPClient
import DiscordUtilities
import GitHubAPI
import Logging
import Models
import NIOCore
import NIOPosix
import Rendering
import Testing

@testable import GHHooksLambda
@testable import Penny

@Suite
struct LeafRenderTests {
    let ghHooksRenderClient = RenderClient(
        renderer: try! .forGHHooks(
            httpClient: .shared,
            logger: Logger(label: "RenderClientGHHooksTests")
        )
    )

    let pennyRenderClient = RenderClient(
        renderer: try! .forPenny(
            httpClient: .shared,
            logger: Logger(label: "Tests_Penny+LeafRendering"),
            on: HTTPClient.shared.eventLoopGroup.next()
        )
    )

    init() {}

    @Test
    func translationNeededDescription() async throws {
        let rendered = try await ghHooksRenderClient.translationNeededDescription(number: 1)
        #expect(rendered.count > 20)
    }

    @Test
    func newReleaseDescription() async throws {
        do {
            let rendered = try await ghHooksRenderClient.newReleaseDescription(
                context: .init(
                    pr: .init(
                        title: "PR title right here",
                        body: """
                            > This PR is really good!
                            > pls accept!
                            """,
                        author: "0xTim",
                        number: 833
                    ),
                    isNewContributor: true,
                    reviewers: ["joannis", "vzsg"],
                    merged_by: "MahdiBM",
                    repo: .init(fullName: "vapor/async-kit"),
                    release: .init(
                        oldTag: "1.0.0",
                        newTag: "4.8.9"
                    )
                )
            )

            expectMultilineStringsEqual(
                rendered,
                """
                ## What's Changed
                PR title right here by @0xTim in #833

                > This PR is really good!
                > pls accept!

                ## New Contributor
                - @0xTim made their first contribution in #833 🎉

                ## Reviewers
                Thanks to the reviewers for their help:
                - @joannis
                - @vzsg

                ###### _This patch was released by @MahdiBM_

                **Full Changelog**: https://github.com/vapor/async-kit/compare/1.0.0...4.8.9
                """
            )
        }

        do {
            let rendered = try await ghHooksRenderClient.newReleaseDescription(
                context: .init(
                    pr: .init(
                        title: "PR title right here",
                        body: """
                            > This PR is really good!
                            > pls accept!
                            """,
                        author: "0xTim",
                        number: 833
                    ),
                    isNewContributor: false,
                    reviewers: [],
                    merged_by: "MahdiBM",
                    repo: .init(fullName: "vapor/async-kit"),
                    release: .init(
                        oldTag: "1.0.0",
                        newTag: "4.8.9"
                    )
                )
            )

            expectMultilineStringsEqual(
                rendered,
                """
                ## What's Changed
                PR title right here by @0xTim in #833

                > This PR is really good!
                > pls accept!



                ###### _This patch was released by @MahdiBM_

                **Full Changelog**: https://github.com/vapor/async-kit/compare/1.0.0...4.8.9
                """
            )
        }
    }

    @Test
    func ticketReport() async throws {
        do {
            let rendered = try await ghHooksRenderClient.ticketReport(
                title: "Some more improvements",
                body: """
                    - Use newer Swift and AWSCLI v2, unpin from very old CloudFormation action, and ditch old deploy actions in global deploy-api-docs workflow.
                    """
            )

            expectMultilineStringsEqual(
                rendered,
                """
                ### Some more improvements

                >>> - Use newer Swift and AWSCLI v2, unpin from very old CloudFormation action, and ditch old deploy actions in global deploy-api-docs workflow.
                """
            )
        }

        do {
            let rendered = try await ghHooksRenderClient.ticketReport(
                title: "Some more improvements",
                body: ""
            )

            expectMultilineStringsEqual(
                rendered,
                """
                ### Some more improvements
                """
            )
        }
    }

    @Test
    func autoPingsHelp() async throws {
        let rendered = try await pennyRenderClient.autoPingsHelp(
            context: .init(
                commands: .init(
                    add: "</auto-pings add:1>",
                    remove: "</auto-pings remove:1>",
                    list: "</auto-pings list:1>",
                    test: "</auto-pings test:1>"
                ),
                isTypingEmoji: DiscordUtils.customAnimatedEmoji(
                    name: "is_typing",
                    id: "1087429908466253984"
                ),
                defaultExpression: S3AutoPingItems.Expression.Kind.default.UIDescription
            )
        )

        expectMultilineStringsEqual(
            rendered,
            #"""
            ## Auto-Pings Help

            You can add texts to be pinged for.
            When someone uses those texts, Penny will DM you about the message.

            - Penny can't DM you about messages in channels which Penny doesn't have access to (such as the role-related channels)

            > All auto-pings commands are ||private||, meaning they are visible to you and you only, and won't even trigger the <a:is_typing:1087429908466253984> indicator.

            ### Adding Expressions

            You can add multiple texts using </auto-pings add:1>, separating the texts using commas (`,`). This command is Slack-compatible so you can copy-paste your Slack keywords to it.

            - Using 'mode' argument You can configure penny to look for exact matches or plain containment. Defaults to 'Containment'.

            - All texts are **case-insensitive** (e.g. `a` == `A`), **diacritic-insensitive** (e.g. `a` == `á` == `ã`) and also **punctuation-insensitive**. Some examples of punctuations are: `“!?-_/\(){}`.

            - All texts are **space-sensitive**.

            > Make sure Penny is able to DM you. You can enable direct messages for Vapor server members under your Server Settings.

            ### Removing Expressions

            You can remove multiple texts using </auto-pings remove:1>, separating the texts using commas (`,`).

            ### Your Pings List

            You can use </auto-pings list:1> to see your current expressions.

            ### Testing Expressions

            You can use </auto-pings test:1> to test if a message triggers some expressions.
            """#
        )
    }
}
