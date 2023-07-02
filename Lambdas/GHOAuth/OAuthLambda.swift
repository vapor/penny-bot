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
    let discordClient: any DiscordClient
    let jsonDecoder: JSONDecoder
    let jsonEncoder: JSONEncoder

    init(context: LambdaInitializationContext) async throws {
        self.client = HTTPClient(eventLoopGroupProvider: .shared(context.eventLoop))
        self.logger = context.logger

        let awsClient = AWSClient(httpClientProvider: .shared(client))
        self.secretsRetriever = SecretsRetriever(awsClient: awsClient, logger: logger)

        let botToken = try await secretsRetriever.getSecret(arnEnvVarKey: "BOT_TOKEN_ARN")
        self.discordClient = await DefaultDiscordClient(httpClient: client, token: botToken)

        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
    }

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async -> APIGatewayV2Response {
        logger.trace("Received event: \(event)")

        guard let code = event.queryStringParameters?["code"] else {
            return .init(statusCode: .badRequest, body: "Missing code query parameter")
        }

        let accessToken: String

        do {
            accessToken = try await getAccessToken(code: code)
        } catch {
            return .init(statusCode: .badRequest, body: "Error getting access token: \(error)")
        }

        let userID: Int

        do {
            userID = try await getUserID(accessToken: accessToken)
        } catch {
            return .init(statusCode: .badRequest, body: "Error getting user: \(error)")
        }

        // TODO: Link id to Discord user

        return .init(statusCode: .ok, body: "Account linking successful, you can return to Discord now")
    }

    // write two functions to abstract the two requests from the above method

    func getAccessToken(code: String) async throws -> String {
        logger.trace("Retrieving secrets")

        let clientSecret = try await secretsRetriever.getSecret(arnEnvVarKey: "GH_CLIENT_SECRET_ARN")
        guard let clientID = ProcessInfo.processInfo.environment["GH_CLIENT_ID"] else {
            throw OAuthLambdaError.envVarNotFound(name: "GH_CLIENT_ID")
        }

        // https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps

        logger.trace("Requesting GitHub access token")
        var request = HTTPClientRequest(url: "https://github.com/login/oauth/access_token")
        request.method = .POST
        request.headers = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        let requestBody = try jsonEncoder.encode([
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code
        ])
        request.body = .bytes(requestBody)

        let response = try await client.execute(request, timeout: .seconds(30))
        logger.trace("Got response: \(response.status)")

        guard response.status == .ok else {
            throw OAuthLambdaError.badResponse(status: Int(response.status.code))
        }

        let responseBody = try await response.body.collect(upTo: 1024 * 1024)
        let accessToken = try jsonDecoder.decode(AccessTokenResponse.self, from: responseBody).accessToken

        return accessToken
    }

    func getUserID(accessToken: String) async throws -> Int {
        logger.trace("Requesting GitHub user info")

        // https://docs.github.com/en/rest/users/users?apiVersion=2022-11-28#get-the-authenticated-user

        var request = HTTPClientRequest(url: "https://api.github.com/user")
        request.method = .GET
        request.headers = [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(accessToken)",
            "X-GitHub-Api-Version": "2022-11-28"
        ]

        let response = try await client.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            throw OAuthLambdaError.badResponse(status: Int(response.status.code))
        }

        let userResponseBody = try await response.body.collect(upTo: 1024 * 1024)
        let id = try jsonDecoder.decode(User.self, from: userResponseBody).id
        
        logger.info("Got user id: \(id)")

        return id
    }
}
