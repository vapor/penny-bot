import Foundation
import DiscordBM

enum Constants {
    static func env(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
    static let vaporGuildId: GuildSnowflake = "431917998102675485"
    static let botDevUserId: UserSnowflake = "290483761559240704"
    static var botToken: String! = env("BOT_TOKEN")
    static var botId: String = env("BOT_APP_ID")!
    static var loggingWebhookUrl: String! = env("LOGGING_WEBHOOK_URL")
    static var apiBaseUrl: String! = env("API_BASE_URL")

    enum ServerEmojis {
        case coin
        case vapor
        case love

        var id: EmojiSnowflake {
            switch self {
            case .coin: return "473588485962596352"
            case .vapor: return "431934596121362453"
            case .love: return "656303356280832062"
            }
        }

        var name: String {
            switch self {
            case .coin: return "coin"
            case .vapor: return "vapor"
            case .love: return "vaporlove"
            }
        }

        var emoji: String {
            DiscordUtils.customEmoji(name: self.name, id: self.id)
        }
    }

    enum Channels: ChannelSnowflake {
        case logs = "1067060193982156880"
        case proposals = "1104650517549953094"
        case thanks = "443074453719744522"

        var id: ChannelSnowflake {
            self.rawValue
        }
    }
    
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
    }
}
