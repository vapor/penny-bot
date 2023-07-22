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
    
    let awsClient: AWSClient
    let userService: UserService
    
    init(context: LambdaInitializationContext) async {
        let awsClient = AWSClient(
            httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop)
        )
        // setup your resources that you want to reuse for every invocation here.
        self.awsClient = awsClient
        self.userService = UserService(awsClient, context.logger)
    }
    
    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async -> APIGatewayV2Response {
        do {
            let request = try event.decode(as: CoinRequest.self)
            switch request {
            case .addCoin(let addCoin):
                return await handleAddCoinRequest(request: addCoin, logger: context.logger)
            case .getCoinCount(let user):
                return await handleGetCoinCountRequest(id: user, logger: context.logger)
            case .getGitHubID(let user):
                return await handleGetGitHubID(id: user, logger: context.logger)
            }
        } catch {
            context.logger.error("Received a bad request", metadata: [
                "event": "\(event)"
            ])
            return APIGatewayV2Response(
                status: .badRequest,
                content: GatewayFailure(reason: "Error: \(error)")
            )
        }
    }
    
    func handleAddCoinRequest(
        request: CoinRequest.AddCoin,
        logger: Logger
    ) async -> APIGatewayV2Response {
        let from = DynamoUser(
            id: UUID(),
            discordID: request.from,
            githubID: request.from,
            numberOfCoins: 0,
            coinEntries: [],
            createdAt: Date())
        
        let user = DynamoUser(
            id: UUID(),
            discordID: request.receiver,
            githubID: request.receiver,
            numberOfCoins: 0,
            coinEntries: [],
            createdAt: Date())
        
        do {
            let userUUID = try await userService.getUserUUID(from: from, with: request.source)
            let coinEntry = CoinEntry(
                id: UUID(),
                createdAt: Date(),
                amount: request.amount,
                from: userUUID,
                source: request.source,
                reason: request.reason)

            let coinResponse = try await userService.addCoins(
                with: coinEntry,
                fromDiscordID: request.from,
                to: user
            )

            logger.debug("Added coins", metadata: [
                "add-coin-request": "\(request)",
                "coinResponse": "\(coinResponse)",
            ])

            return APIGatewayV2Response(status: .ok, content: coinResponse)
        } catch UserService.ServiceError.failedToUpdate {
            return APIGatewayV2Response(
                status: .notFound,
                content: GatewayFailure(reason: "Couldn't find the user")
            )
        } catch {
            logger.error("Can't add coin", metadata: [
                "request": "\(request)"
            ])
            return APIGatewayV2Response(
                status: .expectationFailed,
                content: GatewayFailure(reason: "Error: \(error)")
            )
        }
    }
    
    func handleGetCoinCountRequest(id: String, logger: Logger) async -> APIGatewayV2Response {
        do {
            let coinCount = try await userService.getUserWith(discordID: id)?.numberOfCoins ?? 0
            logger.debug("Got coin count", metadata: [
                "id": .string(id),
                "count": .stringConvertible(coinCount)
            ])
            return APIGatewayV2Response(statusCode: .ok, body: "\(coinCount)")
        } catch {
            logger.error("Can't retrieve coin-count", metadata: [
                "id": .string(id)
            ])
            return APIGatewayV2Response(
                status: .expectationFailed,
                content: GatewayFailure(reason: "Error: \(error)")
            )
        }
    }

    func handleGetGitHubID(id: String, logger: Logger) async -> APIGatewayV2Response {
        do {
            let gitHubID = try await userService.getUserWith(discordID: id)?.githubID
            logger.debug("Got GitHubID", metadata: [
                "id": .string(id),
                "github-id": .string(gitHubID ?? "<null>"),
            ])
            let response: GitHubIDResponse = gitHubID.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .notLinked : .id($0)
            } ?? .notLinked
            return APIGatewayV2Response(status: .ok, content: response)
        } catch {
            logger.error("Can't retrieve github id", metadata: [
                "id": .string(id)
            ])
            return APIGatewayV2Response(
                status: .expectationFailed,
                content: GatewayFailure(reason: "Error: \(error)")
            )
        }
    }
}
