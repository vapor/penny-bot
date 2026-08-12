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
        try await LambdaRuntime { (event: UsersLambdaRequest, context: LambdaContext) in
            let handler = UsersHandler(context: context, sharedContext: sharedContext)
            return await handler.handle(event)
        }.run()
    }

    init(context: LambdaContext, sharedContext: SharedContext) {
        self.sharedContext = sharedContext
        self.internalService = InternalUsersService(awsClient: sharedContext.awsClient, logger: context.logger)
        self.logger = context.logger
    }

    func handle(_ event: UsersLambdaRequest) async -> LambdaResult<UsersLambdaResponse> {
        do {
            switch event {
            case let .addCoin(entry):
                return .success(try await handleAddCoin(entry: entry))
            case let .getOrCreateUser(discordID):
                return .success(.user(try await internalService.getOrCreateUser(discordID: discordID)))
            case let .getUser(githubID):
                return .success(.userIfFound(try await internalService.getUser(githubID: githubID)))
            case let .linkGitHubID(discordID, toGitHubID):
                try await internalService.linkGithubID(discordID: discordID, githubID: toGitHubID)
                return .success(.done)
            case let .unlinkGitHubID(discordID):
                try await internalService.unlinkGithubID(discordID: discordID)
                return .success(.done)
            }
        } catch {
            self.logger.error(
                "Received error while handling request",
                metadata: [
                    "event": "\(event)",
                    "error": .string(String(reflecting: error)),
                ]
            )
            return .failure(reason: "Error: \(error)")
        }
    }

    func handleAddCoin(
        entry: UsersLambdaRequest.CoinEntryRequest
    ) async throws -> UsersLambdaResponse {
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

        return .coinAdded(coinResponse)
    }
}
