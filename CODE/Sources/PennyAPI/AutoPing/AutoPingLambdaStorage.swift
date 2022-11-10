import AWSLambdaRuntime

public enum AutoPingLambdaStorage {
    public static var autoPingLambdaHandlerType: any LambdaHandler.Type = AutoPingHandler.self 
}
