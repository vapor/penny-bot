import AsyncHTTPClient
import AWSLambdaRuntime
import AWSLambdaEvents
import SotoCore
import DiscordBM
import Models
import JWTKit
import LambdasShared
import SharedServices
import Logging
import Foundation

@main
struct GHOAuthHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let client: HTTPClient
    let logger: Logger
    let secretsRetriever: SecretsRetriever
    let userService: UserService
    let signers: JWTSigners

    let jsonDecoder = JSONDecoder()
    let jsonEncoder = JSONEncoder()

    /// We don't do this in the initializer to avoid a possible unnecessary
    /// `secretsRetriever.getSecret()` call which costs $$$.
    var discordClient: any DiscordClient {
        get async throws {
            let botToken = try await secretsRetriever.getSecret(arnEnvVarKey: "BOT_TOKEN_ARN")
            return await DefaultDiscordClient(httpClient: client, token: botToken)
        }
    }

    init(context: LambdaInitializationContext) async throws {
        self.client = HTTPClient(eventLoopGroupProvider: .shared(context.eventLoop))
        self.logger = context.logger

        let awsClient = AWSClient(httpClientProvider: .shared(client))
        self.secretsRetriever = SecretsRetriever(awsClient: awsClient, logger: logger)

        self.userService = UserService(awsClient, logger)

        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()

        signers = JWTSigners()
        signers.use(.es256(key: try getJWTSignersPublicKey()))
    }

    private func getJWTSignersPublicKey() throws -> ECDSAKey {
        logger.debug("Retrieving JWT signer secrets")
        guard let publicKeyString = ProcessInfo.processInfo.environment["ACCOUNT_LINKING_OAUTH_FLOW_PUB_KEY"] else {
            throw Errors.envVarNotFound(name: "ACCOUNT_LINKING_OAUTH_FLOW_PUB_KEY")
        }
        guard let publicKeyData = Data(base64Encoded: publicKeyString) else {
            throw Errors.invalidPublicKey
        }
        return try ECDSAKey.public(pem: publicKeyData)
    }

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async -> APIGatewayV2Response {
        logger.debug("Received event: \(event)")

        guard let code = event.queryStringParameters?["code"] else {
            return .init(statusCode: .badRequest, body: "Missing code query parameter")
        }

        let accessToken: String

        do {
            accessToken = try await getGHAccessToken(code: code)
        } catch {
            logger.error("Error getting access token", metadata: [
                "error": "\(String(reflecting: error))"
            ])
            return .init(statusCode: .badRequest, body: "Error getting access token")
        }

        let user: User

        do {
            user = try await getGHUser(accessToken: accessToken)
        } catch {
            logger.error("Error getting user ID", metadata: [
                "error": "\(String(reflecting: error))"
            ])
            return .init(statusCode: .badRequest, body: "Error getting user")
        }

        let jwt: GHOAuthPayload

        logger.debug("Verifying state")
        do {
            jwt = try signers.verify(String(event.queryStringParameters?["state"] ?? ""), as: GHOAuthPayload.self)
        } catch {
            logger.error("Error during state verification", metadata: [
                "error": "\(String(reflecting: error))",
                "state": .string(event.queryStringParameters?["state"] ?? "")
            ])
            return .init(statusCode: .badRequest, body: "Error verifying state")
        }

        do {
            try await userService.linkGithubID(discordID: jwt.discordID.rawValue, githubID: "\(user.id)")
        } catch {
            logger.error("Error linking user to GitHub account", metadata: [
                "discordID": .stringConvertible(jwt.discordID),
                "githubID": .stringConvertible(user.id),
            ])
            return .init(statusCode: .badRequest, body: "Error linking user")
        }

        do {
            try await discordClient.updateOriginalInteractionResponse(
                token: jwt.interactionToken,
                payload: .init(
                    embeds: [.init(
                        description: "Successfully linked your Discord account to GitHub account with username: \(user.login)",
                        color: .green
                    )]
                )
            ).guardSuccess()
        } catch {
            logger.warning("Received Discord error while updating interaction", metadata: [
                "error": "\(String(reflecting: error))"
            ])
        }

        return .init(statusCode: .ok, body: "Account linking successful, you can return to Discord now")
    }

    func getGHAccessToken(code: String) async throws -> String {
        logger.debug("Retrieving GitHub client secrets")

        let clientSecret = try await secretsRetriever.getSecret(arnEnvVarKey: "GH_CLIENT_SECRET_ARN")
        guard let clientID = ProcessInfo.processInfo.environment["GH_CLIENT_ID"] else {
            throw Errors.envVarNotFound(name: "GH_CLIENT_ID")
        }

        // https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps

        logger.debug("Requesting GitHub access token")
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
        let responseBody = try await response.body.collect(upTo: 1 << 22)
        logger.debug("Got response \(response.status): headers: \(response.headers), body: \(responseBody)")

        guard response.status == .ok else {
            throw Errors.badResponse(status: Int(response.status.code))
        }

        let accessToken = try jsonDecoder.decode(AccessTokenResponse.self, from: responseBody).accessToken

        return accessToken
    }

    func getGHUser(accessToken: String) async throws -> User {
        logger.debug("Requesting GitHub user info")

        // https://docs.github.com/en/rest/users/users?apiVersion=2022-11-28#get-the-authenticated-user

        var request = HTTPClientRequest(url: "https://api.github.com/user")
        request.headers = [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(accessToken)",
            "X-GitHub-Api-Version": "2022-11-28"
        ]

        let response = try await client.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            throw Errors.badResponse(status: Int(response.status.code))
        }

        let userResponseBody = try await response.body.collect(upTo: 1024 * 1024)
        let user = try jsonDecoder.decode(User.self, from: userResponseBody)
        
        logger.info("Got user with id: \(user.id)")

        return user
    }
}
