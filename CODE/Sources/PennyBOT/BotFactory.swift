import DiscordBM
import AsyncHTTPClient
import NIOCore
import Foundation

enum BotFactory {
    static var makeBot: (any EventLoopGroup, HTTPClient) -> any GatewayManager = {
        eventLoopGroup, client in
        guard let token = Constants.botToken, let appId = Constants.botId else {
            fatalError("Missing 'BOT_TOKEN' or 'BOT_APP_ID' env vars")
        }
        return BotGatewayManager(
            eventLoopGroup: eventLoopGroup,
            httpClient: client,
            token: token,
            appId: appId,
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
}
