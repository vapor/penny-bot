import AWSLambdaRuntime

public enum LambdaHandlerStorage {
    public static var coinLambdaHandlerType: any LambdaHandler.Type = AddCoinHandler.self 
}
