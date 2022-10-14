import DiscordBM
import AsyncHTTPClient
import NIOCore
import Foundation

enum BotFactory {
    static var makeBot: (EventLoopGroup, HTTPClient) -> GatewayManager = {
        eventLoopGroup, client in
        guard let token = ProcessInfo.processInfo.environment["BOT_TOKEN"],
              let appId = ProcessInfo.processInfo.environment["BOT_APP_ID"] else {
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
            intents: [.guildMessages, .messageContent, .guildMessageReactions]
        )
    }
}
