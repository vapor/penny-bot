import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore

struct Response: Codable {
    let body: String
}

@main
struct AddCoins: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    let awsClient: AWSClient
    
    let userService: UserService
    
    init(context: Lambda.InitializationContext) async throws {
        // setup your resources that you want to reuse for every invocation here.
        self.awsClient = AWSClient(
            httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop))
        self.userService = UserService(awsClient, context.logger)
    }
    
    func shutdown(context: Lambda.ShutdownContext) async throws {
        try? awsClient.syncShutdown()
    }

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        let response: APIGatewayV2Response
        
        context.logger.info("Reading incoming request:\(event)")
                
        switch (event.context.http.path, event.context.http.method) {
        case ("/coin", .GET):
            response = APIGatewayV2Response(statusCode: .ok, body: "This is an AWS Lambda response made in swift")
        case("/coin", .POST):
            do {
                let product: Coin = try event.bodyObject()
                
                let coinEntry = CoinEntry(id: UUID(), createdAt: Date(), amount: 1, from: UUID(), source: .discord, reason: .userProvided)
                let user = User(id: UUID(), discordID: product.receiver, githubID: nil, numberOfCoins: 0, coinEntries: [], createdAt: Date())
                
                let message = try await userService.addCoins(with: coinEntry, to: user)
                response = APIGatewayV2Response(statusCode: .ok, body: message)
            }
            catch let error {
                //let error = APIError.invalidRequest
                response = APIGatewayV2Response(statusCode: .badRequest, body: String(describing: error))
                
            }
        default:
            response = APIGatewayV2Response(statusCode: .notFound)
        }
        return response
    }
}

public enum APIError: Error{
    case invalidItem
    case tableNameNotFound
    case invalidRequest
    case invalidHandler
}
