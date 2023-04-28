import DiscordBM
import Foundation
import Logging
import NIOPosix
import NIOCore
import AsyncHTTPClient
import Backtrace
import ServiceLifecycle

actor MainService: Service {
    func run() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let client = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))

        await bootstrapLoggingSystem(httpClient: client)

        let bot = BotFactory.makeBot(eventLoopGroup, client)
        let cache = await BotFactory.makeCache(bot)

        await DiscordService.shared.initialize(discordClient: bot.client, cache: cache)
        await DefaultPingsService.shared.initialize(httpClient: client)
        await CommandsManager().registerCommands()
        await BotStateManager.shared.initialize()

        await bot.connect()

        for await event in await bot.makeEventStream() {
            EventHandler(
                event: event,
                coinService: ServiceFactory.makeCoinService(client)
            ).handle()
        }
    }

    private func bootstrapLoggingSystem(httpClient: HTTPClient) async {
#if DEBUG
        // Discord-logging is disabled in debug based on the logger configuration,
        // so we can just use a fake url.
        let webhookUrl = "https://discord.com/api/webhooks/1066284436045439037/dSs4nFhjpxcOh6HWD_"
#else
        guard let webhookUrl = Constants.loggingWebhookUrl else {
            fatalError("Missing 'LOGGING_WEBHOOK_URL' env var")
        }
#endif
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            httpClient: httpClient,
            configuration: .init(
                aliveNotice: .init(
                    address: try! .url(webhookUrl),
                    interval: nil,
                    message: "I'm Alive! :)",
                    initialNoticeMention: .user(Constants.botDevUserId)
                ),
                mentions: [
                    .warning: .user(Constants.botDevUserId),
                    .error: .user(Constants.botDevUserId),
                    .critical: .user(Constants.botDevUserId)
                ],
                extraMetadata: [.warning, .error, .critical],
                disabledLogLevels: [.debug, .trace],
                disabledInDebug: true
            )
        )
        await LoggingSystem.bootstrapWithDiscordLogger(
            address: try! .url(webhookUrl),
            level: .trace,
            makeMainLogHandler: { label, metadataProvider in
                StreamLogHandler.standardOutput(label: label, metadataProvider: metadataProvider)
            }
        )
    }
}

private class UnsafeBox<Value>: @unchecked Sendable {
    var value: Value

    init(value: Value) {
        self.value = value
    }
}
