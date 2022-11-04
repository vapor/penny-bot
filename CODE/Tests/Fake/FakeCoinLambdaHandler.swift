import PennyLambdaAddCoins
import AWSLambdaRuntime
import AWSLambdaEvents
import PennyModels
import Foundation
import PennyServices
import Logging
import SotoCore

public struct FakeCoinLambdaHandler: LambdaHandler {
    public typealias Event = APIGatewayV2Request
    public typealias Output = APIGatewayV2Response
    
    let userService: UserService
    
    public init(context: LambdaInitializationContext) async throws {
        // The 'client' won't be used at all, but still needs to be passed to user service
        let client = AWSClient(httpClientProvider: .createNew)
        self.userService = .init(client, Logger(label: "Test_UserService"))
        context.terminator.register(name: "Shut Down") { eventLoop in
            try! client.syncShutdown()
            return eventLoop.makeSucceededVoidFuture()
        }
    }
    
    public func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
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
