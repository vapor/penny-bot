import AWSLambdaEvents
import AWSLambdaRuntime
import AsyncHTTPClient
import HTTPTypes
import LambdasShared
import Models
import Shared
import SotoCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@main
@dynamicMemberLookup
struct UsersHandler {
    struct SharedContext {
        let httpClient: HTTPClient
        let awsClient: AWSClient
    }

    subscript<T>(dynamicMember keyPath: KeyPath<SharedContext, T>) -> T {
        sharedContext[keyPath: keyPath]
    }

    let sharedContext: SharedContext
    let internalService: InternalUsersService
    let logger: Logger

    static func main() async throws {
        let httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(Lambda.defaultEventLoop),
            configuration: .forPenny
        )
        let awsClient = AWSClient(httpClient: httpClient)
        let sharedContext = SharedContext(httpClient: httpClient, awsClient: awsClient)
        try await LambdaRuntime { (event: APIGatewayV2Request, context: LambdaContext) in
            let handler = UsersHandler(context: context, sharedContext: sharedContext)
            return await handler.handle(event)
        }.run()
    }

    init(context: LambdaContext, sharedContext: SharedContext) {
        self.sharedContext = sharedContext
        self.internalService = InternalUsersService(awsClient: sharedContext.awsClient, logger: context.logger)
        self.logger = context.logger
    }

    func handle(_ event: APIGatewayV2Request) async -> APIGatewayV2Response {
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
            self.logger.error(
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
