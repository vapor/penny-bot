import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import PennyServices
import PennyModels
import PennyExtensions

@main
struct AddCoinHandler: LambdaHandler {
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
        context.terminator.register(name: "Shutdown AWS", handler: { eventLoop in
            eventLoop.makeFutureWithTask {
                try await awsClient.shutdown()
            }
        })
    }
    
    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async -> APIGatewayV2Response {
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
            
            return APIGatewayV2Response(status: .ok, content: coinResponse)
        }
        catch UserService.ServiceError.failedToUpdate {
            return APIGatewayV2Response(
                status: .notFound,
                content: GatewayFailure(reason: "Couldn't find the user")
            )
        }
        catch let error {
            return APIGatewayV2Response(
                status: .badRequest,
                content: GatewayFailure(reason: "Error: \(error)")
            )
        }
    }
}
