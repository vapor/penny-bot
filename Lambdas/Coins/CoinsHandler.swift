import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import SharedServices
import Models
import Extensions

@main
struct CoinsHandler: LambdaHandler {
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
            let request = try event.decode(as: CoinRequest.self)
            switch request {
            case .addCoin(let entry):
                return try await handleAddCoinRequest(entry: entry)
            case .getUser(let discordID):
                return try await handleGetUserRequest(discordID: discordID)
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
    
    func handleAddCoinRequest(
        entry: CoinRequest.DiscordCoinEntry
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
        let newUser = try await userService.addCoinEntry(coinEntry, to: toUser)

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
    
    func handleGetUserRequest(discordID: UserSnowflake) async throws -> APIGatewayV2Response {
        let user = try await userService.getOrCreateUser(discordID: discordID)
        return APIGatewayV2Response(status: .ok, content: user)
    }
}
