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
            /// Shutdown in reverse order (clients first, then the ELG)
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

        #warning("this")

//        sendTestMessage(client: bot.client)
//        return


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

#warning("this")
import DiscordHTTP
func sendTestMessage(client: any DiscordClient) async throws {
    let creatorName = "mahdibm"
    let creatorLink = "https://github.com/mahdibm"

    let prLink = "https://github.com/vapor/redis/pull/209"

    let bod: String? = """
            - Cleanup CI a little
            - Update README
            - Move CONTRIBUTING.md to .github
            - Make tests more reliable
            """

    let body = bod.map { ">>> \($0)".unicodesPrefix(264) } ?? ""

    let description = """
            > \("some\nthing\nmhh")

            """

    try await client.createMessage(
        channelId: "1016614538398937098",
        payload: .init(
            content: "https://google.com"
        )
    ).guardSuccess()
}
