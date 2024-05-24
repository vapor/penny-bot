import NIOPosix
import AsyncHTTPClient
import Shared
import SotoS3

@main
struct Penny {
    static func main() async throws {
        try await start(mainService: PennyService())
    }

    static func start(mainService: any MainService) async throws {
        /// Use `1` instead of `System.coreCount`.
        /// This is preferred for apps that primarily use structured concurrency.
        let httpClient = HTTPClient(
            eventLoopGroup: MultiThreadedEventLoopGroup.singleton,
            configuration: .forPenny
        )
        let awsClient = AWSClient(httpClient: httpClient)

        try await mainService.bootstrapLoggingSystem(httpClient: httpClient)

        let bot = try await mainService.makeBot(
            httpClient: httpClient
        )
        let cache = try await mainService.makeCache(bot: bot)

        let context = try await mainService.beforeConnectCall(
            bot: bot,
            cache: cache,
            httpClient: httpClient,
            awsClient: awsClient
        )

        await bot.connect()

        try await mainService.afterConnectCall(context: context)

        for await event in await bot.events {
            EventHandler(event: event, context: context).handle()
        }

        /// These shutdown calls are only useful for tests where we call `Penny.main()` repeatedly
        /// Shutdown in reverse order of dependance.
        try await awsClient.shutdown()
        try await httpClient.shutdown()
    }
}
