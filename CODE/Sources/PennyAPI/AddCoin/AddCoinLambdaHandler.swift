import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import PennyServices
import PennyModels

struct Response: Codable {
    let body: String
}

struct FailedToShutdownAWSError: Error {
    let message = "Failed to shutdown the AWS Client"
}

@main
struct AddCoins: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    let awsClient: AWSClient
    
    let userService: UserService
    
    init(context: LambdaInitializationContext) async throws {
        let awsClient = AWSClientFactory.makeClient(context.eventLoop)
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

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        let response: APIGatewayV2Response
        do {
            let product: CoinRequest = try event.bodyObject()
            
            let from = User(
                id: UUID(),
                discordID: product.from,
                githubID: product.from,
                numberOfCoins: 0,
                coinEntries: [],
                createdAt: Date())
            
            let user = User(
                id: UUID(),
                discordID: product.receiver,
                githubID: product.receiver,
                numberOfCoins: 0,
                coinEntries: [],
                createdAt: Date())
            
            let userUUID = try await userService.getUserUUID(from: from, with: product.source)
            let coinEntry = CoinEntry(
                id: UUID(),
                createdAt: Date(),
                amount: product.amount,
                from: userUUID,
                source: product.source,
                reason: product.reason)
            
            let coinResponse = try await userService.addCoins(
                with: coinEntry,
                fromDiscordID: product.from,
                to: user
            )
            let data = try JSONEncoder().encode(coinResponse)
            let string = String(data: data, encoding: .utf8)
            response = APIGatewayV2Response(statusCode: .ok, body: string)
        }
        catch UserService.ServiceError.failedToUpdate {
            response = APIGatewayV2Response(statusCode: .notFound, body: "ERROR- The user in particular wasn't found.")
        }
        catch let error {
            response = APIGatewayV2Response(statusCode: .badRequest, body: "ERROR- \(error.localizedDescription)")
            
        }
        return response
    }
}
