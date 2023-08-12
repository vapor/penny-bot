import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation
import LambdasShared
import Models
import SotoCore

@main
struct UsersHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let internalService: InternalUsersService
    let logger: Logger

    init(context: LambdaInitializationContext) async {
        let awsClient = AWSClient(
            httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop)
        )
        self.internalService = InternalUsersService(awsClient: awsClient, logger: context.logger)
        self.logger = context.logger
    }

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async -> APIGatewayV2Response {
        do {
            let request = try event.decode(as: UserRequest.self)
            switch request {
            case let .addCoin(entry):
                return try await handleAddUserRequest(entry: entry)
            case let .getOrCreateUser(discordID):
                return try await handleGetOrCreateUserRequest(discordID: discordID)
            case let .getUser(githubID):
                return try await handleGetUserRequest(githubID: githubID)
            case let .linkGitHubID(discordID, toGitHubID):
                return try await handleLinkGitHubRequest(discordID: discordID, githubID: toGitHubID)
            case let .unlinkGitHubID(discordID):
                return try await handleUnlinkGitHubRequest(discordID: discordID)
            }
        } catch {
            context.logger.error(
                "Received error while handling request",
                metadata: [
                    "event": "\(event)",
                    "error": .string(String(reflecting: error)),
                ]
            )
            return APIGatewayV2Response(
                status: .badRequest,
                content: GatewayFailure(reason: "Error: \(error)")
            )
        }
    }

    func handleAddUserRequest(
        entry: UserRequest.CoinEntryRequest
    ) async throws -> APIGatewayV2Response {
        let fromUserID = try await internalService.getOrCreateUser(discordID: entry.fromDiscordID).id
        let toUser = try await internalService.getOrCreateUser(discordID: entry.toDiscordID)
        let coinEntry = CoinEntry(
            fromUserID: fromUserID,
            toUserID: toUser.id,
            amount: entry.amount,
            source: entry.source,
            reason: entry.reason
        )
        let newUser = try await internalService.addCoinEntry(coinEntry, freshUser: toUser)

        let coinResponse = CoinResponse(
            sender: entry.fromDiscordID,
            receiver: entry.toDiscordID,
            newCoinCount: newUser.coinCount
        )

        logger.debug(
            "Added coins",
            metadata: [
                "entry": "\(entry)",
                "coinResponse": "\(coinResponse)",
            ]
        )

        return APIGatewayV2Response(status: .ok, content: coinResponse)
    }

    func handleGetOrCreateUserRequest(discordID: UserSnowflake) async throws -> APIGatewayV2Response {
        let user = try await internalService.getOrCreateUser(discordID: discordID)
        return APIGatewayV2Response(status: .ok, content: user)
    }

    func handleGetUserRequest(githubID: String) async throws -> APIGatewayV2Response {
        let user = try await internalService.getUser(githubID: githubID)
        return APIGatewayV2Response(status: .ok, content: user)
    }

    func handleLinkGitHubRequest(
        discordID: UserSnowflake,
        githubID: String
    ) async throws -> APIGatewayV2Response {
        try await internalService.linkGithubID(discordID: discordID, githubID: githubID)
        return APIGatewayV2Response(statusCode: .ok)
    }

    func handleUnlinkGitHubRequest(discordID: UserSnowflake) async throws -> APIGatewayV2Response {
        try await internalService.unlinkGithubID(discordID: discordID)
        return APIGatewayV2Response(statusCode: .ok)
    }
}
