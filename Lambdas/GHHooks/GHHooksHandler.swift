import AWSLambdaRuntime
import AWSLambdaEvents
import AsyncHTTPClient
import SotoSecretsManager
import Crypto
import DiscordHTTP
import Extensions
import Foundation

@main
struct GHHooksHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let httpClient: HTTPClient
    let awsClient: AWSClient
    let secretsManager: SecretsManager
    let logger: Logger

    init(context: LambdaInitializationContext) async {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(context.eventLoop))
        self.awsClient = AWSClient(httpClientProvider: .shared(httpClient))
        self.secretsManager = SecretsManager(client: awsClient)
        self.logger = context.logger
    }

    func handle(
        _ request: APIGatewayV2Request,
        context: LambdaContext
    ) async throws -> APIGatewayV2Response {
        logger.trace("Got request", metadata: [
            "request": "\(request)"
        ])
        try await verifyWebhookSignature(request: request)
        logger.debug("Verified signature")

        guard let _eventName = request.headers.first(name: "x-gitHub-event"),
              let eventName = GHEvent.Kind(rawValue: _eventName) else {
            throw Errors.headerNotFound(name: "x-gitHub-event", headers: request.headers)
        }

        logger.trace("Event name is '\(eventName)'")

        /// To make sure we don't miss pings because of a decoding error or something
        if eventName == .ping {
            return APIGatewayV2Response(statusCode: .ok)
        }

        let client = try await makeDiscordClient()

        let event: GHEvent
        do {
            event = try request.decode(as: GHEvent.self)
        } catch {
            try await client.createMessage(
                channelId: Constants.Channels.logs.id,
                payload: .init(embeds: [.init(
                    title: "Failed decoding for event \(eventName.rawValue)",
                    color: .red
                )])
            ).guardSuccess()
            throw error
        }

        logger.debug("Decoded event", metadata: [
            "event": "\(event)"
        ])

        /// This is for testing purposes for now:

        switch eventName {
        case .issues, .pull_request:
            try await client.createMessage(
                channelId: Constants.Channels.logs.id,
                payload: .init(embeds: [.init(
                    title: "Received event \(eventName)",
                    description: """
                    Action: \(event.action ?? "null")
                    Repo: \(event.repository.name)
                    """,
                    color: .yellow
                )])
            ).guardSuccess()
        case .ping:
            /// Already handled
            break
        default:
            try await client.createMessage(
                channelId: Constants.Channels.logs.id,
                payload: .init(embeds: [.init(
                    title: "Received UNHANDLED event \(eventName)",
                    description: """
                    Action: \(event.action ?? "null")
                    Repo: \(event.repository.name)
                    """,
                    color: .red
                )])
            ).guardSuccess()
        }

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
        let secret = try await getSecret(arnEnvVarKey: "WH_SECRET_ARN")
        let data = Data(secret.utf8)
        return SymmetricKey(data: data)
    }

    func makeDiscordClient() async throws -> any DiscordClient {
        let botToken = try await getSecret(arnEnvVarKey: "BOT_TOKEN_ARN")
        return await DefaultDiscordClient(httpClient: httpClient, token: botToken)
    }

    func getSecret(arnEnvVarKey: String) async throws -> String {
        guard let arn = ProcessInfo.processInfo.environment[arnEnvVarKey] else {
            throw Errors.envVarNotFound(name: arnEnvVarKey)
        }
        let secret = try await secretsManager.getSecretValue(
            .init(secretId: arn),
            logger: logger
        )
        guard let secret = secret.secretString else {
            throw Errors.secretNotFound(arn: arn)
        }
        return secret
    }
}
