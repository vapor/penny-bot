import SotoCore

enum AWSClientFactory {
    static var makeClient: (EventLoop) -> AWSClient = {
        AWSClient(httpClientProvider: .createNewWithEventLoopGroup($0))
    }
}
