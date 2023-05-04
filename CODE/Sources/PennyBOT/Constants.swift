import Foundation
import DiscordBM

enum Constants {
    static func env(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
    static let vaporGuildId: GuildSnowflake = "431917998102675485"
    static let logsChannelId: ChannelSnowflake = "1067060193982156880"
    static let thanksChannelId: ChannelSnowflake = "443074453719744522"
    static let botDevUserId: UserSnowflake = "290483761559240704"
    static var botToken: String! = env("BOT_TOKEN")
    static var botId: String! = env("BOT_APP_ID")
    static var loggingWebhookUrl: String! = env("LOGGING_WEBHOOK_URL")
    static var apiBaseUrl: String! = env("API_BASE_URL")
    /// Vapor's custom coin emoji in Discord's format.
    static let vaporCoinEmoji = DiscordUtils.customEmoji(name: "coin", id: "473588485962596352")
    static let vaporLoveEmoji = DiscordUtils.customEmoji(name: "vaporlove", id: "656303356280832062")
    
    enum Roles: RoleSnowflake {
        case nitroBooster = "621412660973535233"
        case backer = "431921695524126722"
        case sponsor = "444167329748746262"
        case contributor = "431920712505098240"
        case maintainer = "530113860129259521"
        case moderator = "431920836631592980"
        case core = "431919254372089857"
        
        static let elevatedPublicCommandsAccess: [Roles] = [
            .nitroBooster,
            .backer,
            .sponsor,
            .contributor,
            .maintainer,
            .moderator,
            .core,
        ]

        static let elevatedRestrictedCommandsAccess: [Roles] = [
            .contributor,
            .maintainer,
            .moderator,
            .core,
        ]
    }
}
