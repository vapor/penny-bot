import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import PennyServices
import PennyModels

struct FailedToShutdownAWSError: Error {
    let message = "Failed to shutdown the AWS Client"
}

@main
struct AddCoinHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    let awsClient: AWSClient
    let userService: UserService
    
    init(context: LambdaInitializationContext) async throws {
        let awsClient = AWSClient(
            httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop)
        )
        // setup your resources that you want to reuse for every invocation here.
        self.awsClient = awsClient
        self.userService = UserService(awsClient, context.logger)
        context.terminator.register(name: "Shutdown AWS", handler: { eventloop in
            do {
                try awsClient.syncShutdown()
                return eventloop.makeSucceededVoidFuture()
            } catch {
                return eventloop.makeFailedFuture(FailedToShutdownAWSError())
            }
        })
    }
    
    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async -> APIGatewayV2Response {
        do {
            let request: CoinRequest = try event.bodyObject()
            switch request {
            case .addCoin(let addCoin):
                return await handleAddCoinRequest(request: addCoin)
            case .getCoinCount(let user):
                return await handleGetCoinCountRequest(id: user)
            }
        } catch {
            context.logger.error("Received a bad request. Event: \(event)")
            return APIGatewayV2Response(statusCode: .badRequest, body: "ERROR- \(error.localizedDescription)")
        }
    }
    
    func handleAddCoinRequest(request: CoinRequest.AddCoin) async -> APIGatewayV2Response {
        let from = User(
            id: UUID(),
            discordID: request.from,
            githubID: request.from,
            numberOfCoins: 0,
            coinEntries: [],
            createdAt: Date())
        
        let user = User(
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
            let data = try JSONEncoder().encode(coinResponse)
            let string = String(data: data, encoding: .utf8)
            return APIGatewayV2Response(statusCode: .ok, body: string)
        } catch UserService.ServiceError.failedToUpdate {
            return APIGatewayV2Response(statusCode: .notFound, body: "ERROR- The user in particular wasn't found.")
        } catch {
            return APIGatewayV2Response(statusCode: .badRequest, body: "ERROR- \(error.localizedDescription)")
        }
    }
    
    func handleGetCoinCountRequest(id: String) async -> APIGatewayV2Response {
        do {
            let coinCount = try await userService.getUserWith(discordID: id)?.numberOfCoins ?? 0
            return APIGatewayV2Response(statusCode: .ok, body: "\(coinCount)")
        } catch {
            return APIGatewayV2Response(statusCode: .badRequest, body: "ERROR- \(error.localizedDescription)")
        }
    }
}

