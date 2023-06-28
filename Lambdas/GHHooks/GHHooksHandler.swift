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
        try await verifyWebhookSignature(request: request)
        guard let eventName = request.headers.first(where: { $0.key == "X-GitHub-Event" }) else {
            throw Errors.headerNotFound(name: "X-GitHub-Event", headers: request.headers)
        }
        var event = try request.decode(as: GithubEvent.self)
        event.name = eventName.value

        let client = try await makeDiscordClient()

        /// This is for testing purposes for now

        try await client.createMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(embeds: [.init(
                title: "Received \(event.name ?? "null")",
                description: """
                Action: \(event.action ?? "null")
                Repo: \(event.repository.name)
                """,
                color: .yellow
            )])
        ).guardSuccess()

        return APIGatewayV2Response(statusCode: .ok)
    }

    func verifyWebhookSignature(request: APIGatewayV2Request) async throws {
        guard let signature = request.headers.first(
            where: { $0.key == "X-Hub-Signature-256" }
        )?.value else {
            throw Errors.headerNotFound(name: "X-Hub-Signature-256", headers: request.headers)
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
