import AWSLambdaRuntime
import AWSLambdaEvents

@main
struct AddCoin {
    static func main() {
        LambdaHandlerStorage.coinLambdaHandlerType.main()
    }
}
