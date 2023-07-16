import AWSLambdaRuntime
import AWSLambdaEvents
import AsyncHTTPClient
import OpenAPIAsyncHTTPClient
import SotoCore
import DiscordHTTP
import GitHubAPI
import DiscordUtilities
import Crypto
import Logging
import Extensions
import Foundation

@main
struct GHHooksHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let httpClient: HTTPClient
    let githubClient: Client
    let secretsRetriever: SecretsRetriever
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
        context.logger.trace("Handler will initialize")

        self.logger = context.logger
        /// We can remove this if/when the lambda runtime gets support for
        /// bootstrapping the logging system which it appears to not have.
        DiscordGlobalConfiguration.makeLogger = { _ in context.logger }

        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(context.eventLoop))

        let awsClient = AWSClient(httpClientProvider: .shared(self.httpClient))
        self.secretsRetriever = SecretsRetriever(awsClient: awsClient, logger: logger)

        let authenticator = Authenticator(
            secretsRetriever: secretsRetriever,
            httpClient: httpClient,
            logger: logger
        )
        let middleware = GHMiddleware(
            authorization: .authenticator(authenticator),
            logger: logger
        )

        let transport = AsyncHTTPClientTransport(configuration: .init(
            client: httpClient,
            timeout: .seconds(3)
        ))
        self.githubClient = Client(
            serverURL: try Servers.server1(),
            transport: transport,
            middlewares: [middleware]
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
                    channelId: Constants.Channels.logs.id,
                    payload: .init(
                        content: DiscordUtils.mention(id: UserSnowflake("290483761559240704")),
                        embeds: [.init(
                            title: "GHHooks lambda top-level error",
                            description: "\(error)".unicodesPrefix(4_000),
                            color: .red
                        )]
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
        logger.trace("Verified signature")

        guard let _eventName = request.headers.first(name: "x-github-event"),
              let eventName = GHEvent.Kind(rawValue: _eventName) else {
            throw Errors.headerNotFound(name: "x-gitHub-event", headers: request.headers)
        }

        logger.debug("Event name is '\(eventName)'")

        /// To make sure we don't miss pings because of a decoding error or something
        if eventName == .ping {
            logger.trace("Will pong and return")
            return APIGatewayV2Response(statusCode: .ok)
        }

        let event = try request.decodeWithISO8601(as: GHEvent.self)

        logger.trace("Decoded event", metadata: [
            "event": "\(event)"
        ])

        try await EventHandler(
            context: .init(
                eventName: eventName,
                event: event,
                discordClient: discordClient,
                githubClient: githubClient,
                logger: logger
            )
        ).handle()

        logger.trace("Event handled")

        return APIGatewayV2Response(statusCode: .ok)
    }

    func verifyWebhookSignature(request: APIGatewayV2Request) async throws {
        guard let signature = request.headers.first(name: "x-hub-signature-256") else {
            throw Errors.headerNotFound(name: "x-hub-signature-256", headers: request.headers)
        }
        let hmacMessageData = Data((request.body ?? "").utf8)
        let secret = try await getWebhookSecret()
        var hmac = HMAC<SHA256>.init(key: secret)
        hmac.update(data: hmacMessageData)
        let mac = hmac.finalize()
        let expectedSignature = "sha256=" + mac.hexDigest()
        guard signature == expectedSignature else {
            throw Errors.signaturesDoNotMatch(found: signature, expected: expectedSignature)
        }
    }

    func getWebhookSecret() async throws -> SymmetricKey {
        let secret = try await secretsRetriever.getSecret(arnEnvVarKey: "WH_SECRET_ARN")
        let data = Data(secret.value.utf8)
        return SymmetricKey(data: data)
    }
}
