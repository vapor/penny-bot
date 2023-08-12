import AWSLambdaEvents
import AWSLambdaRuntime
import AsyncHTTPClient
import DiscordBM
import JWTKit
import LambdasShared
import Logging
import Models
import Shared
import SotoCore

#if canImport(Darwin)
import Foundation
#else
@preconcurrency import Foundation
#endif

@main
struct GHOAuthHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let client: HTTPClient
    let secretsRetriever: SecretsRetriever
    let userService: any UsersService
    let signers: JWTSigners
    let logger: Logger

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

        guard let apiBaseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] else {
            throw Errors.envVarNotFound(name: "API_BASE_URL")
        }
        self.userService = ServiceFactory.makeUsersService(
            httpClient: client,
            apiBaseURL: apiBaseURL
        )

        signers = JWTSigners()
        signers.use(.es256(key: try getJWTSignersPublicKey()))
    }

    private func getJWTSignersPublicKey() throws -> ECDSAKey {
        logger.debug("Retrieving JWT signer secrets")
        let pubKeyEnvVarKey = "ACCOUNT_LINKING_OAUTH_FLOW_PUB_KEY"
        guard let publicKeyString = ProcessInfo.processInfo.environment[pubKeyEnvVarKey] else {
            throw Errors.envVarNotFound(name: pubKeyEnvVarKey)
        }
        guard let publicKeyData = Data(base64Encoded: publicKeyString) else {
            throw Errors.invalidPublicKey
        }
        return try ECDSAKey.public(pem: publicKeyData)
    }

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async -> APIGatewayV2Response
    {
        logger.debug("Received event: \(event)")

        guard let code = event.queryStringParameters?["code"] else {
            return .init(statusCode: .badRequest, body: "Missing code query parameter")
        }

        let accessToken: String

        do {
            accessToken = try await getGHAccessToken(code: code)
        } catch {
            logger.error(
                "Error getting access token",
                metadata: [
                    "error": "\(String(reflecting: error))"
                ]
            )
            return .init(statusCode: .badRequest, body: "Error getting access token")
        }

        let user: User

        do {
            user = try await getGHUser(accessToken: accessToken)
        } catch {
            logger.error(
                "Error getting user ID",
                metadata: [
                    "error": "\(String(reflecting: error))",
                    "accessToken": .string(accessToken),
                ]
            )
            return .init(statusCode: .badRequest, body: "Error getting user")
        }

        let jwt: GHOAuthPayload

        logger.debug("Verifying state")
        do {
            jwt = try signers.verify(
                String(event.queryStringParameters?["state"] ?? ""),
                as: GHOAuthPayload.self
            )
        } catch {
            logger.error(
                "Error during state verification",
                metadata: [
                    "error": "\(String(reflecting: error))",
                    "state": .string(event.queryStringParameters?["state"] ?? ""),
                ]
            )
            return .init(statusCode: .badRequest, body: "Error verifying state")
        }

        do {
            try await userService.linkGitHubID(discordID: jwt.discordID, toGitHubID: "\(user.id)")
        } catch {
            logger.error(
                "Error linking user to GitHub account",
                metadata: [
                    "jwt": "\(jwt)",
                    "githubID": .stringConvertible(user.id),
                    "error": .string(String(reflecting: error)),
                ]
            )
            return .init(statusCode: .badRequest, body: "Error linking user")
        }

        do {
            let encodedLogin = user.login.urlPathEncoded()
            let url = "https://github.com/\(encodedLogin)"
            try await discordClient.updateOriginalInteractionResponse(
                token: jwt.interactionToken,
                payload: .init(
                    embeds: [
                        .init(
                            description: """
                                Successfully linked your GitHub account with username: [\(user.login)](\(url))
                                """,
                            color: .green
                        )
                    ]
                )
            )
            .guardSuccess()
        } catch {
            logger.warning(
                "Received Discord error while updating interaction",
                metadata: [
                    "error": "\(String(reflecting: error))"
                ]
            )
        }

        return .init(
            statusCode: .ok,
            body: "Account linking successful, you can return to Discord now"
        )
    }

    func getGHAccessToken(code: String) async throws -> String {
        logger.debug("Retrieving GitHub client secrets")

        let clientSecret = try await secretsRetriever.getSecret(
            arnEnvVarKey: "GH_CLIENT_SECRET_ARN"
        )
        guard let clientID = ProcessInfo.processInfo.environment["GH_CLIENT_ID"] else {
            throw Errors.envVarNotFound(name: "GH_CLIENT_ID")
        }

        // https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps

        logger.debug("Requesting GitHub access token")
        var request = HTTPClientRequest(url: "https://github.com/login/oauth/access_token")
        request.method = .POST
        request.headers = [
            "Accept": "application/json",
            "Content-Type": "application/json",
        ]
        let requestBody = try jsonEncoder.encode([
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
        ])
        request.body = .bytes(requestBody)

        let response = try await client.execute(request, timeout: .seconds(5))
        let body = try await response.body.collect(upTo: 1 << 22)

        logger.debug(
            "Got access token response",
            metadata: [
                "status": .stringConvertible(response.status),
                "headers": .stringConvertible(response.headers),
                "body": .string(String(buffer: body)),
            ]
        )

        guard response.status == .ok else {
            throw Errors.httpRequestFailed(response: response, body: String(buffer: body))
        }

        let accessToken = try jsonDecoder.decode(AccessTokenResponse.self, from: body).accessToken

        return accessToken
    }

    func getGHUser(accessToken: String) async throws -> User {
        logger.debug("Requesting GitHub user info")

        // https://docs.github.com/en/rest/users/users?apiVersion=2022-11-28#get-the-authenticated-user

        var request = HTTPClientRequest(url: "https://api.github.com/user")
        request.headers = [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(accessToken)",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "Penny/1.0.0 (https://github.com/vapor/penny-bot)",
        ]

        let response = try await client.execute(request, timeout: .seconds(5))
        let body = try await response.body.collect(upTo: 1024 * 1024)

        logger.debug(
            "Got user with access token response",
            metadata: [
                "status": .stringConvertible(response.status),
                "headers": .stringConvertible(response.headers),
                "body": .string(String(buffer: body)),
            ]
        )

        guard response.status == .ok else {
            throw Errors.httpRequestFailed(response: response, body: String(buffer: body))
        }

        let user = try jsonDecoder.decode(User.self, from: body)

        logger.info("Got user: \(user)")

        return user
    }
}
