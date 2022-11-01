import AWSLambdaRuntime
import AWSLambdaEvents

public enum LambdaHandlerFactory {
    
    public static var makeCoinLambdaHandler: (LambdaInitializationContext) async throws -> any CoinLambdaHandler = {
        try await AddCoinHandler(context: $0)
    }
}

// MARK: - CoinLambdaHandler
public protocol CoinLambdaHandler: LambdaHandler
where Event == APIGatewayV2Request,
      Output == APIGatewayV2Response {
}
