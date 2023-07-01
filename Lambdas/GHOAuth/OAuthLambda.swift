import AsyncHTTPClient
import AWSLambdaRuntime
import AWSLambdaEvents
import DiscordBM
import Foundation
import SotoSecretsManager
import GHHooksLambda
import Models

@main
struct GHOAuthHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let client: HTTPClient
    let logger: Logger
    let secretsRetriever: SecretsRetriever

    init(context: LambdaInitializationContext) {
        self.client = HTTPClient(eventLoopGroupProvider: .shared(context.eventLoop))
        self.logger = context.logger
        let awsClient = AWSClient(httpClientProvider: .shared(client))
        self.secretsRetriever = SecretsRetriever(awsClient: awsClient, logger: logger)
    }

    func handle(
        _ event: APIGatewayV2Request,
        context: LambdaContext
    ) async throws -> APIGatewayV2Response {
        logger.trace("Received event: \(event)")

        guard let code = event.queryStringParameters?["code"] else {
            return .init(
                statusCode: .badRequest,
                body: "Missing code query parameter"
            )
        }

        logger.trace("Retrieving secrets")
        let clientID = try await secretsRetriever.getSecret(arnEnvVarKey: "BOT_TOKEN_ARN")
        let clientSecret = try await secretsRetriever.getSecret(arnEnvVarKey: "WH_SECRET_ARN")

        // https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps

        logger.trace("Requesting GitHub access token")
        var request = HTTPClientRequest(url: "https://github.com/login/oauth/access_token")
        request.method = .POST
        request.headers = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        let requestBody = try JSONEncoder().encode([
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code
        ])
        request.body = .bytes(requestBody)

        let response = try await client.execute(request, timeout: .seconds(30))
        logger.trace("Got response: \(response.status)")

        guard response.status == .ok else {
            return .init(
                statusCode: .internalServerError,
                body: "Unexpected response from GitHub: \(response.status)"
            )
        }

        let responseBody = try await response.body.collect(upTo: 1024 * 1024)
        let accessToken = try JSONDecoder().decode(AccessTokenResponse.self, from: responseBody).accessToken

        // https://docs.github.com/en/rest/users/users?apiVersion=2022-11-28#get-the-authenticated-user

        logger.trace("Requesting GitHub user info")

        request = HTTPClientRequest(url: "https://api.github.com/user")
        request.method = .GET
        request.headers = [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(accessToken)"
        ]

        let userResponse = try await client.execute(request, timeout: .seconds(30))

        guard userResponse.status == .ok else {
            return .init(
                statusCode: .internalServerError,
                body: "Unexpected response from GitHub: \(userResponse.status)"
            )
        }

        let userResponseBody = try await userResponse.body.collect(upTo: 1024 * 1024)
        let id = try JSONDecoder().decode(User.self, from: userResponseBody).id
        
        logger.trace("Got user id: \(id)")

        // TODO: Link id to Discord user

        return .init(statusCode: .ok)
    }
}
