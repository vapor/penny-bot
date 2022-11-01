import AWSLambdaRuntime
import AWSLambdaEvents

public enum LambdaHandlerStorage {
    
    public static var coinLambdaHandlerType: any LambdaHandler.Type = AddCoinHandler.self 
}
