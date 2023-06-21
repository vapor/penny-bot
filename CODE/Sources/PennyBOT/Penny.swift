import DiscordBM
import Foundation
import NIOPosix
import NIOCore
import AsyncHTTPClient
import Backtrace

@main
struct Penny {
    static func main() async throws {
        Backtrace.install()

        /// Use `1` instead of `System.coreCount`.
        /// This is preferred for apps that primarily use structured concurrency.
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let client = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))

        /// These shutdown calls are only useful for tests where we call `Penny.main()` repeatedly
        defer {
            /// Shutdown in reverse order (client first, then the ELG)
            try! client.syncShutdown()
            try! eventLoopGroup.syncShutdownGracefully()
        }

        await DiscordFactory.bootstrapLoggingSystem(client)

        let bot = await DiscordFactory.makeBot(eventLoopGroup, client)
        let cache = await DiscordFactory.makeCache(bot)

        await DiscordService.shared.initialize(discordClient: bot.client, cache: cache)
        await ServiceFactory.makePingsService().initialize(httpClient: client)
        await ServiceFactory.makeHelpsService().initialize(httpClient: client)
        await DefaultCoinService.shared.initialize(httpClient: client)
        await ServiceFactory.initializeAndRunProposalsChecker(client)
        await CommandsManager().registerCommands()
        await BotStateManager.shared.initialize()

        await bot.connect()

        let stream = await bot.makeEventsStream()
        for await event in stream {
            EventHandler(event: event).handle()
        }
    }
}
