import AWSLambdaRuntime
import AWSLambdaEvents
import AsyncHTTPClient
import SotoCore
import DiscordHTTP
import GitHubAPI
import Rendering
import DiscordUtilities
import Logging
import LambdasShared
import Shared
import Foundation

@main
struct GHHooksHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let httpClient: HTTPClient
    let githubClient: Client
    let secretsRetriever: SecretsRetriever
    let messageLookupRepo: any MessageLookupRepo
    let logger: Logger

    /// We don't do this in the initializer to avoid a possible unnecessary
    /// `secretsRetriever.getSecret()` call which costs $$$.
    var discordClient: any DiscordClient {
        get async throws {
            let botToken = try await secretsRetriever.getSecret(arnEnvVarKey: "BOT_TOKEN_ARN")
            return await DefaultDiscordClient(httpClient: httpClient, token: botToken)
        }
    }

    init(context: LambdaInitializationContext) async throws {
        self.logger = context.logger
        /// We can remove this if/when the lambda runtime gets support for
        /// bootstrapping the logging system which it appears to not have.
        DiscordGlobalConfiguration.makeLogger = { _ in context.logger }

        self.httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(context.eventLoop),
            configuration: .forPenny
        )

        let awsClient = AWSClient(httpClient: self.httpClient)
        self.secretsRetriever = SecretsRetriever(awsClient: awsClient, logger: logger)

        let authenticator = Authenticator(
            secretsRetriever: secretsRetriever,
            httpClient: httpClient,
            logger: logger
        )

        self.githubClient = try .makeForGitHub(
            httpClient: httpClient,
            authorization: .computedBearer { isRetry in
                try await authenticator.generateAccessToken(
                    forceRefreshToken: isRetry
                )
            },
            logger: logger
        )

        self.messageLookupRepo = DynamoMessageRepo(
            awsClient: awsClient,
            logger: logger
        )

        context.logger.trace("Handler did initialize")
    }

    func handle(
        _ request: APIGatewayV2Request,
        context: LambdaContext
    ) async throws -> APIGatewayV2Response {
        do {
            return try await handleThrowing(request, context: context)
        } catch {
            do {
                /// Report to Discord server for easier notification of maintainers
                try await discordClient.createMessage(
                    channelId: Constants.Channels.botLogs.id,
                    payload: .init(
                        content: DiscordUtils.mention(id: Constants.botDevUserID),
                        embeds: [.init(
                            title: "GHHooks lambda top-level error",
                            description: "\(error)".unicodesPrefix(2_048),
                            color: .red
                        )],
                        files: [.init(
                            data: ByteBuffer(string: "\(error)"),
                            filename: "error"
                        )],
                        attachments: [.init(index: 0, filename: "error")]
                    )
                ).guardSuccess()
            } catch {
                logger.error("DiscordClient logging error", metadata: [
                    "error": "\(error)"
                ])
            }
            throw error
        }
    }

    func handleThrowing(
        _ request: APIGatewayV2Request,
        context: LambdaContext
    ) async throws -> APIGatewayV2Response {
        logger.debug("Got request", metadata: [
            "request": "\(request)"
        ])

        try await verifyWebhookSignature(request: request)

        guard let _eventName = request.headers.first(name: "x-github-event"),
              let eventName = GHEvent.Kind(rawValue: _eventName) else {
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
        logger.trace("Decoded event", metadata: [
            "event": "\(event)"
        ])

        let apiBaseURL = try requireEnvVar("API_BASE_URL")
        try await EventHandler(
            context: .init(
                eventName: eventName,
                event: event,
                httpClient: httpClient,
                discordClient: discordClient,
                githubClient: githubClient,
                renderClient: RenderClient(
                    renderer: try .forGHHooks(
                        httpClient: httpClient,
                        logger: logger
                    )
                ),
                messageLookupRepo: self.messageLookupRepo,
                usersService: ServiceFactory.makeUsersService(
                    httpClient: httpClient,
                    apiBaseURL: apiBaseURL
                ),
                logger: logger
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
        let secret = try await secretsRetriever.getSecret(arnEnvVarKey: "WH_SECRET_ARN")
        try Verifier.verifyWebhookSignature(
            signatureHeader: signature,
            requestBody: body,
            secret: secret
        )
        logger.trace("Did verify webhook signature")
    }
}
