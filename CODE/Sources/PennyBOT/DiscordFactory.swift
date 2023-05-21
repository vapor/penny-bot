import DiscordBM
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
            cachingBehavior: .custom(apiEndpoints: [
                .listApplicationCommands: 60 * 60 /// 1 hour
            ])
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
}
