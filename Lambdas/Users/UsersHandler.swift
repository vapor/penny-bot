import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import Models
import Extensions

@main
struct UsersHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let userService: UserService
    let logger: Logger

    init(context: LambdaInitializationContext) async {
        let awsClient = AWSClient(
            httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop)
        )
        self.userService = UserService(awsClient: awsClient, logger: context.logger)
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
            }
        } catch {
            context.logger.error("Received error while handling request", metadata: [
                "event": "\(event)",
                "error": .string(String(reflecting: error))
            ])
            return APIGatewayV2Response(
                status: .badRequest,
                content: GatewayFailure(reason: "Error: \(error)")
            )
        }
    }
    
    func handleAddUserRequest(
        entry: UserRequest.CoinEntryRequest
    ) async throws -> APIGatewayV2Response {
        let fromUserID = try await userService.getOrCreateUser(discordID: entry.fromDiscordID).id
        let toUser = try await userService.getOrCreateUser(discordID: entry.toDiscordID)
        let coinEntry = CoinEntry(
            fromUserID: fromUserID,
            toUserID: toUser.id,
            amount: entry.amount,
            source: entry.source,
            reason: entry.reason
        )
        let newUser = try await userService.addCoinEntry(coinEntry, freshUser: toUser)

        let coinResponse = CoinResponse(
            sender: entry.fromDiscordID,
            receiver: entry.toDiscordID,
            newCoinCount: newUser.coinCount
        )

        logger.debug("Added coins", metadata: [
            "entry": "\(entry)",
            "coinResponse": "\(coinResponse)"
        ])

        return APIGatewayV2Response(status: .ok, content: coinResponse)
    }
    
    func handleGetOrCreateUserRequest(discordID: UserSnowflake) async throws -> APIGatewayV2Response {
        let user = try await userService.getOrCreateUser(discordID: discordID)
        return APIGatewayV2Response(status: .ok, content: user)
    }

    func handleGetUserRequest(githubID: String) async throws -> APIGatewayV2Response {
        let user = try await userService.getUser(githubID: githubID)
        return APIGatewayV2Response(status: .ok, content: user)
    }

    func handleLinkGitHubRequest(
        discordID: UserSnowflake,
        githubID: String
    ) async throws -> APIGatewayV2Response {
        try await userService.linkGithubID(discordID: discordID, githubID: githubID)
        return APIGatewayV2Response(statusCode: .ok)
    }
}
