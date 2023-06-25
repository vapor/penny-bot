import DiscordBM
import DiscordLogger
import Logging
import AsyncHTTPClient
import NIOCore
import Foundation

enum DiscordFactory {
    static var makeBot: (any EventLoopGroup, HTTPClient) async -> any GatewayManager = {
        eventLoopGroup, client in
        guard let token = Constants.botToken else {
            fatalError("Missing 'BOT_TOKEN' env var")
        }
        /// Custom caching for the `getApplicationGlobalCommands` endpoint.
        var clientConfiguration = ClientConfiguration(
            cachingBehavior: .custom(
                apiEndpoints: [
                    .listApplicationCommands: .seconds(60 * 60) /// 1 hour
                ],
                apiEndpointsDefaultTTL: .seconds(5)
            )
        )
        return await BotGatewayManager(
            eventLoopGroup: eventLoopGroup,
            httpClient: client,
            clientConfiguration: clientConfiguration,
            token: token,
            presence: .init(
                activities: [.init(name: "Showing Appreciation", type: .game)],
                status: .online,
                afk: false
            ),
            intents: [.guilds, .guildMembers, .guildMessages, .messageContent, .guildMessageReactions]
        )
    }
    
    static var makeCache: (any GatewayManager) async -> DiscordCache = {
        await DiscordCache(
            gatewayManager: $0,
            intents: [.guilds, .guildMembers],
            requestAllMembers: .enabled
        )
    }

    static var bootstrapLoggingSystem: (HTTPClient) async -> Void = { httpClient in
#if DEBUG
        // Discord-logging is disabled in debug based on the logger configuration,
        // so we can just use an invalid url
        let webhookUrl = "https://discord.com/api/webhooks/1066284436045439037/dSs4nFhjpxcOh6HWD_"
#else
        guard let webhookUrl = Constants.loggingWebhookUrl else {
            fatalError("Missing 'LOGGING_WEBHOOK_URL' env var")
        }
#endif
        DiscordGlobalConfiguration.logManager = await DiscordLogManager(
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
