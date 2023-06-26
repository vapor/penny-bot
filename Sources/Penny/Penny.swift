import NIOPosix
import AsyncHTTPClient
import SotoS3
import Backtrace

@main
struct Penny {
    static func main() async throws {
        Backtrace.install()

        /// Use `1` instead of `System.coreCount`.
        /// This is preferred for apps that primarily use structured concurrency
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let client = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
        let awsClient = AWSClient(httpClientProvider: .shared(client))

        /// These shutdown calls are only useful for tests where we call `Penny.main()` repeatedly
        defer {
            /// Shutdown in reverse order (client first, then the ELG)
            try! awsClient.syncShutdown()
            try! client.syncShutdown()
            try! eventLoopGroup.syncShutdownGracefully()
        }

        await DiscordFactory.bootstrapLoggingSystem(client)

        let bot = await DiscordFactory.makeBot(eventLoopGroup, client)
        let cache = await DiscordFactory.makeCache(bot)

        await DiscordService.shared.initialize(discordClient: bot.client, cache: cache)
        await ServiceFactory.makePingsService().initialize(httpClient: client)
        await ServiceFactory.makeFaqsService().initialize(httpClient: client)
        await DefaultCoinService.shared.initialize(httpClient: client)
        await DefaultCachesService.shared.initialize(awsClient: awsClient)
        await CommandsManager().registerCommands()

        await bot.connect()
        let stream = await bot.makeEventsStream()

        /// Initialize `BotStateManager` after `bot.connect()` and `bot.makeEventsStream()`.
        /// since it communicates through Discord and will need the Gateway connection.
        await BotStateManager.shared.initialize(onStart: {
            /// ProposalsChecker contains cached stuff and needs to wait for `BotStateManager`.
            await ServiceFactory.initiateProposalsChecker(client)
        })

        for await event in stream {
            EventHandler(event: event).handle()
        }
    }
}
