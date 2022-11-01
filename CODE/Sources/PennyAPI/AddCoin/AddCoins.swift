import AWSLambdaRuntime
import AWSLambdaEvents

@main
struct AddCoin: CoinLambdaHandler {
    
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    let underlyingHandler: any CoinLambdaHandler
    
    init(context: LambdaInitializationContext) async throws {
        self.underlyingHandler = try await LambdaHandlerFactory.makeCoinLambdaHandler(context)
    }
    
    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        try await underlyingHandler.handle(event, context: context)
    }
}
