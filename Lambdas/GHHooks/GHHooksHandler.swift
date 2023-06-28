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

//    public func verifySubscriptionSignature(req: Request) throws {
//        guard let messageId = req.headers.first(name: "Twitch-Eventsub-Message-Id"),
//              let messageTimestamp = req.headers.first(name: "Twitch-Eventsub-Message-Timestamp"),
//              let date = getDate(timestampHeader: messageTimestamp),
//              let signatureHeader = req.headers.first(name: "Twitch-Eventsub-Message-Signature"),
//              let requestBody = req.body.string
//        else {
//            req.logger.error("Could not approve the signature.", metadata: [
//                "description": .string(req.description),
//                "headers": .stringConvertible(
//                    req.headers.filter({ $0.name.hasPrefix("Twitch") })
//                )
//            ])
//            throw Abort(.unauthorized)
//        }
//        let now = Date().timeIntervalSince1970
//        let ageMargin: Double = 600 /// 10 mins, which is what Twitch says in the docs
//        guard (now-ageMargin...now+5).contains(date.timeIntervalSince1970) else {
//            req.logger.error("Could not approve the signature.", metadata: [
//                "description": .string(req.description),
//                "headers": .stringConvertible(
//                    req.headers.filter({ $0.name.hasPrefix("Twitch") })
//                ),
//                "date": "\(date)",
//                "now": "\(now)"
//            ])
//            throw Abort(.unauthorized)
//        }
//        let hmacMessage = messageId + messageTimestamp + requestBody
//        let hmacMessageData = Data(hmacMessage.utf8)
//        let key = subscriptionSecret()
//        var hmac = HMAC<SHA256>.init(key: key)
//        hmac.update(data: hmacMessageData)
//        let mac = hmac.finalize()
//        let expectedSignature = "sha256=" + mac.hex
//
//        guard expectedSignature == signatureHeader else {
//            req.logger.error("Could not verify the signature.", metadata: [
//                "body": .string(requestBody),
//                "signature": .string(signatureHeader),
//                "expectedSignature": .string(expectedSignature),
//                "headers": .stringConvertible(req.headers),
//                "id": .string(messageId)
//            ])
//            throw Abort(.unauthorized)
//        }
//    }
}
