#if canImport(Darwin)
import Foundation
#else
@preconcurrency import Foundation
#endif
import AsyncHTTPClient
import AWSLambdaRuntime
import AWSLambdaEvents
import SotoCore
import DiscordBM
import Models
import JWTKit
import LambdasShared
import Shared
import Logging

@main
struct GHOAuthHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let client: HTTPClient = .shared
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
        self.logger = context.logger

        let awsClient = AWSClient()
        self.secretsRetriever = SecretsRetriever(awsClient: awsClient, logger: logger)

        let apiBaseURL = try requireEnvVar("API_BASE_URL")
        self.userService = ServiceFactory.makeUsersService(apiBaseURL: apiBaseURL)

        signers = JWTSigners()
        signers.use(.es256(key: try getJWTSignersPublicKey()))
    }

    private func getJWTSignersPublicKey() throws -> ECDSAKey {
        logger.debug("Retrieving JWT signer secrets")
        let key = try requireEnvVar("ACCOUNT_LINKING_OAUTH_FLOW_PUB_KEY")
        guard let data = Data(base64Encoded: key) else {
            throw Errors.invalidPublicKey
        }
        let ecdsa = try ECDSAKey.public(pem: data)
        return ecdsa
    }

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async -> APIGatewayV2Response {
        logger.debug("Received event: \(event)")

        guard let code = event.queryStringParameters?["code"] else {
            logger.error("Missing code query parameter")
            await logErrorToDiscord("Missing code query parameter")
            return .init(statusCode: .badRequest, body: "Missing code query parameter")
        }

        guard let state = event.queryStringParameters?["state"] else {
            logger.error("Missing state query parameter")
            await logErrorToDiscord("Missing state query parameter")
            return .init(statusCode: .badRequest, body: "Missing state query parameter")
        }

        logger.trace("Got code and state", metadata: [
            "code": .string(code),
            "state": .string(state),
        ])

        let jwt: GHOAuthPayload

        logger.debug("Verifying state")
        do {
            jwt = try signers.verify(state, as: GHOAuthPayload.self)
        } catch {
            logger.error("Error during state verification", metadata: [
                "error": "\(String(reflecting: error))",
                "state": .string(event.queryStringParameters?["state"] ?? "")
            ])
            await logErrorToDiscord("Error verifying state")
            return .init(statusCode: .badRequest, body: "Error verifying state")
        }

        func updateInteraction(color: DiscordColor, description: String) async {
            do {
                try await discordClient.updateOriginalInteractionResponse(
                    token: jwt.interactionToken,
                    payload: .init(embeds: [.init(
                        description: description,
                        color: color
                    )])
                ).guardSuccess()
            } catch {
                await logErrorToDiscord(
                    "Received Discord error while updating interaction: \(String(reflecting: error))"
                )
                logger.error("Received Discord error while updating interaction", metadata: [
                    "error": "\(String(reflecting: error))"
                ])
            }
        }

        func failure(_ error: String) async -> APIGatewayV2Response {
            await logErrorToDiscord(error)
            await updateInteraction(color: .red, description: error)
            return .init(statusCode: .badRequest, body: error)
        }

        let accessToken: String

        do {
            accessToken = try await getGHAccessToken(code: code)
        } catch {
            logger.error("Error getting access token", metadata: [
                "error": "\(String(reflecting: error))"
            ])
            return await failure("Error getting access token")
        }

        let user: User

        do {
            user = try await getGHUser(accessToken: accessToken)
        } catch {
            logger.error("Error getting user ID", metadata: [
                "error": "\(String(reflecting: error))",
                "accessToken": .string(accessToken)
            ])
            return await failure("Error getting user")
        }

        do {
            try await userService.linkGitHubID(discordID: jwt.discordID, toGitHubID: "\(user.id)")
        } catch {
            logger.error("Error linking user to GitHub account", metadata: [
                "jwt": "\(jwt)",
                "githubID": .stringConvertible(user.id),
                "error": .string(String(reflecting: error))
            ])
            return await failure("Error linking user")
        }

        let encodedLogin = user.login.urlPathEncoded()
        let url = "https://github.com/\(encodedLogin)"
        await updateInteraction(
            color: .green,
            description: """
            Successfully linked your GitHub account with username: [\(user.login)](\(url))
            """
        )

        return .init(statusCode: .ok, body: "Account linking successful, you can return to Discord now.")
    }

    func getGHAccessToken(code: String) async throws -> String {
        logger.debug("Retrieving GitHub client secrets")

        let clientSecret = try await secretsRetriever.getSecret(arnEnvVarKey: "GH_CLIENT_SECRET_ARN")
        let clientID = try requireEnvVar("GH_CLIENT_ID")

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

        let response = try await client.execute(request, timeout: .seconds(5))
        let body = try await response.body.collect(upTo: 1 << 22)

        logger.debug("Got access token response", metadata: [
            "status": .stringConvertible(response.status),
            "headers": .stringConvertible(response.headers),
            "body": .string(String(buffer: body))
        ])

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
            "User-Agent": "Penny/1.0.0 (https://github.com/vapor/penny-bot)"
        ]

        logger.trace("Will send get-GH-user request", metadata: ["accessToken": .string(accessToken)])
        let response = try await client.execute(request, timeout: .seconds(5))
        let body = try await response.body.collect(upTo: 1024 * 1024)

        logger.debug("Got user with access token response", metadata: [
            "status": .stringConvertible(response.status),
            "headers": .stringConvertible(response.headers),
            "body": .string(String(buffer: body))
        ])

        guard response.status == .ok else {
            throw Errors.httpRequestFailed(response: response, body: String(buffer: body))
        }

        let user = try jsonDecoder.decode(User.self, from: body)

        logger.info("Got user: \(user)")

        return user
    }

    func logErrorToDiscord(_ error: String) async {
        do {
            try await discordClient.createMessage(
                channelId: Constants.Channels.botLogs.id,
                payload: .init(embeds: [.init(
                    description: """
                    Error in GHHooks Lambda:

                    >>> \(error)
                    """,
                    color: .red
                )])
            ).guardSuccess()
        } catch {
            logger.warning("Received Discord error while logging", metadata: [
                "error": "\(String(reflecting: error))"
            ])
        }
    }
}
