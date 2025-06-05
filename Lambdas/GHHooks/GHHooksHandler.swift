import AWSLambdaEvents
import AWSLambdaRuntime
import AsyncHTTPClient
import DiscordHTTP
import DiscordUtilities
import GitHubAPI
import HTTPTypes
import LambdasShared
import Logging
import Rendering
import Shared
import SotoCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@main
@dynamicMemberLookup
struct GHHooksHandler {
    struct SharedContext {
        let httpClient: HTTPClient
        let githubClient: Client
        let awsClient: AWSClient
        let secretsRetriever: SecretsRetriever
    }

    subscript<T>(dynamicMember keyPath: KeyPath<SharedContext, T>) -> T {
        sharedContext[keyPath: keyPath]
    }

    let sharedContext: SharedContext
    let messageLookupRepo: any MessageLookupRepo
    let logger: Logger

    /// We don't do this in the initializer to avoid a possible unnecessary
    /// `secretsRetriever.getSecret()` call which costs $$$.
    var discordClient: any DiscordClient {
        get async throws {
            let botToken = try await self.secretsRetriever.getSecret(arnEnvVarKey: "BOT_TOKEN_ARN")
            return await DefaultDiscordClient(httpClient: self.httpClient, token: botToken)
        }
    }

    static func main() async throws {
        let httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(Lambda.defaultEventLoop),
            configuration: .forPenny
        )
        let awsClient = AWSClient(httpClient: httpClient)
        let secretsRetriever = SecretsRetriever(awsClient: awsClient, logger: Logger(label: "GHHooksHandler"))
        let authenticator = Authenticator(
            secretsRetriever: secretsRetriever,
            httpClient: httpClient,
            logger: Logger(label: "GitHubClient.Authenticator")
        )

        let githubClient = try Client.makeForGitHub(
            httpClient: httpClient,
            authorization: .computedBearer { isRetry in
                try await authenticator.generateAccessToken(
                    forceRefreshToken: isRetry
                )
            },
            logger: Logger(label: "GitHubClient")
        )
        let sharedContext = SharedContext(
            httpClient: httpClient,
            githubClient: githubClient,
            awsClient: awsClient,
            secretsRetriever: secretsRetriever
        )
        try await LambdaRuntime { (event: APIGatewayV2Request, context: LambdaContext) in
            let handler = try GHHooksHandler(context: context, sharedContext: sharedContext)
            return try await handler.handle(event)
        }.run()
    }

    init(context: LambdaContext, sharedContext: SharedContext) throws {
        self.sharedContext = sharedContext
        self.logger = context.logger
        self.messageLookupRepo = DynamoMessageRepo(
            awsClient: sharedContext.awsClient,
            logger: logger
        )

        self.logger.trace("Handler did initialize")
    }

    func handle(_ request: APIGatewayV2Request) async throws -> APIGatewayV2Response {
        do {
            return try await handleThrowing(request)
        } catch {
            do {
                /// Report to Discord server for easier notification of maintainers
                try await discordClient.createMessage(
                    channelId: Constants.Channels.botLogs.id,
                    payload: .init(
                        content: DiscordUtils.mention(id: Constants.botDevUserID),
                        embeds: [
                            .init(
                                title: "GHHooks lambda top-level error",
                                description: "\(error)".unicodesPrefix(2_048),
                                color: .red,
                                fields: [
                                    .init(
                                        name: "X-Github-Delivery",
                                        value: request.headers.first(name: "x-github-delivery") ?? "<null>"
                                    )
                                ]
                            )
                        ],
                        /// The `x` suffix is only to make sure Discord doesn't try to inline-render the files.
                        files: [
                            .init(
                                data: ByteBuffer(string: "\(error)"),
                                filename: "error.txtx"
                            ),
                            .init(
                                data: request.body.map(ByteBuffer.init(string:)) ?? ByteBuffer(),
                                filename: "body.jsonx"
                            ),
                        ],
                        attachments: [
                            .init(index: 0, filename: "error.txtx"),
                            .init(index: 1, filename: "body.jsonx"),
                        ]
                    )
                ).guardSuccess()
            } catch {
                logger.error(
                    "DiscordClient logging error",
                    metadata: [
                        "error": "\(error)"
                    ]
                )
            }
            throw error
        }
    }

    func handleThrowing(_ request: APIGatewayV2Request) async throws -> APIGatewayV2Response {
        logger.debug(
            "Got request",
            metadata: [
                "request": "\(request)"
            ]
        )

        try await verifyWebhookSignature(request: request)

        guard let _eventName = request.headers.first(name: "x-github-event"),
            let eventName = GHEvent.Kind(rawValue: _eventName)
        else {
            throw Errors.headerNotFound(name: "x-gitHub-event", headers: request.headers)
        }

        logger.debug("Event name: '\(eventName)'")

        /// To make sure we don't miss pings because of a decoding error or something
        if eventName == .ping {
            logger.trace("Will pong and return")
            return APIGatewayV2Response(statusCode: .ok)
        }

        let event = try request.decodeWithISO8601(as: GHEvent.self)

        logger.debug("Event id: '\(eventName).\(event.action ?? "<null>")'")
        logger.trace(
            "Decoded event",
            metadata: [
                "event": "\(event)"
            ]
        )

        let apiBaseURL = try requireEnvVar("API_BASE_URL")
        try await EventHandler(
            context: .init(
                eventName: eventName,
                event: event,
                httpClient: self.httpClient,
                discordClient: self.discordClient,
                githubClient: self.githubClient,
                renderClient: RenderClient(
                    renderer: try .forGHHooks(
                        httpClient: self.httpClient,
                        logger: self.logger
                    )
                ),
                messageLookupRepo: self.messageLookupRepo,
                usersService: ServiceFactory.makeUsersService(
                    httpClient: self.httpClient,
                    apiBaseURL: apiBaseURL
                ),
                logger: self.logger
            )
        ).handle()

        logger.trace("Event handled")

        return APIGatewayV2Response(statusCode: .ok)
    }

    func verifyWebhookSignature(request: APIGatewayV2Request) async throws {
        logger.trace("Will verify webhook signature")
        guard let signature = request.headers.first(name: "x-hub-signature-256") else {
            throw Errors.headerNotFound(name: "x-hub-signature-256", headers: request.headers)
        }
        let body = Data((request.body ?? "").utf8)
        let secret = try await self.secretsRetriever.getSecret(arnEnvVarKey: "WH_SECRET_ARN")
        try Verifier.verifyWebhookSignature(
            signatureHeader: signature,
            requestBody: body,
            secret: secret
        )
        logger.trace("Did verify webhook signature")
    }
}
