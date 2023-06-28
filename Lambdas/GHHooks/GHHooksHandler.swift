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
        _ event: APIGatewayV2Request,
        context: LambdaContext
    ) async throws -> APIGatewayV2Response {
        try await verifyWebhookSignature(event: event)

        #warning("fix return")
        return APIGatewayV2Response(
            status: .badRequest,
            content: GatewayFailure(reason: "Unimplemented")
        )
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

    func makeDiscordClient() async throws -> any DiscordClient {
        let botToken = try await getSecret(arnEnvVarKey: "BOT_TOKEN_ARN")
        return await DefaultDiscordClient(httpClient: httpClient, token: botToken)
    }

    func getWebhookSecret() async throws -> SymmetricKey {
        let secret = try await getSecret(arnEnvVarKey: "WH_SECRET_ARN")
        let data = Data(secret.utf8)
        return SymmetricKey(data: data)
    }

    func verifyWebhookSignature(event: APIGatewayV2Request) async throws {
        guard let signature = event.headers.first(
            where: { $0.key == "X-Hub-Signature-256" }
        )?.value else {
            throw Errors.signatureHeaderNotFound(headers: event.headers)
        }
        let hmacMessageData = Data((event.body ?? "").utf8)
        let secret = try await getWebhookSecret()
        var hmac = HMAC<SHA256>.init(key: secret)
        hmac.update(data: hmacMessageData)
        let mac = hmac.finalize()
        let expectedSignature = "sha256=" + mac.hexDigest()
        guard signature == expectedSignature else {
            throw Errors.signaturesDoNotMatch(found: signature, expected: expectedSignature)
        }
    }
}
