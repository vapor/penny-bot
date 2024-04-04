import Foundation
import DiscordBM

enum Constants {
    static func env(_ key: String) -> String {
        if let value = ProcessInfo.processInfo.environment[key] {
            return value
        } else {
            fatalError("""
            Set an environment value for key '\(key)'.
            In tests you usually can set dummy values.
            """)
        }
    }
    static let vaporGuildId: GuildSnowflake = "431917998102675485"
    static let botDevUserId: UserSnowflake = "290483761559240704"
    static let botId: UserSnowflake = "950695294906007573"
    static let botToken = env("BOT_TOKEN")
    static let loggingWebhookURL = env("LOGGING_WEBHOOK_URL")
    static let apiBaseURL = env("API_BASE_URL")
    static let ghOAuthClientID = env("GH_OAUTH_CLIENT_ID")
    static let accountLinkOAuthPrivKey = env("ACCOUNT_LINKING_OAUTH_FLOW_PRIV_KEY")

    /// U+1F3FB EMOJI MODIFIER FITZPATRICK TYPE-1-2...TYPE-6
    static var emojiSkins: [String] {
        ["", "\u{1f3fb}", "\u{1f3fc}", "\u{1f3fd}", "\u{1f3fe}", "\u{1f3ff}"]
    }
    /// U+2640 FEMALE SIGN, U+2642 MALE SIGN, U+200D ZWJ, U+FE0F VARIATION SELECTOR 16
    static var emojiGenders: [String] {
        ["", "\u{200d}\u{2640}\u{fe0f}", "\u{200d}\u{2642}\u{fe0f}"]
    }

    enum StackOverflow {
        static let apiKey = env("SO_API_KEY")
    }

    enum ServerEmojis {
        case coin
        case vapor
        case love
        case doge

        var id: EmojiSnowflake {
            switch self {
            case .coin: return "473588485962596352"
            case .vapor: return "431934596121362453"
            case .love: return "656303356280832062"
            case .doge: return "460388864046137355"
            }
        }

        var name: String {
            switch self {
            case .coin: return "coin"
            case .vapor: return "vapor"
            case .love: return "vaporlove"
            case .doge: return "doge"
            }
        }

        var emoji: String {
            DiscordUtils.customEmoji(name: self.name, id: self.id)
        }
    }

    enum Channels: ChannelSnowflake {
        case welcome = "437050958061764608"
        case news = "431917998102675487"
        case publications = "435934451046809600"
        case release = "431926479752921098"
        case jobs = "442420282292961282"
        case status = "459521920241500220"
        case thanks = "443074453719744522"
        case logs = "1067060193982156880"
        case moderators = "443512396900859904"
        case issuesAndPRs = "1123702585006768228"
        case evolution = "1104650517549953094"
        case stackOverflow = "473249028142923787"

        var id: ChannelSnowflake {
            self.rawValue
        }

        /// Must not send thanks-responses to these channels.
        /// Instead send to the #thanks channel.
        static let thanksResponseDenyList: Set<ChannelSnowflake> = Set([
            Channels.welcome,
            Channels.news,
            Channels.publications,
            Channels.release,
            Channels.jobs,
            Channels.status,
        ].map(\.id))

        static let announcementChannels: Set<ChannelSnowflake> = Set([
            Channels.news,
            Channels.publications,
            Channels.release,
            Channels.jobs,
            Channels.stackOverflow,
            Channels.issuesAndPRs,
            Channels.evolution,
        ].map(\.id))
    }

    enum Roles: RoleSnowflake {
        case nitroBooster = "621412660973535233"
        case backer = "431921695524126722"
        case sponsor = "444167329748746262"
        case contributor = "431920712505098240"
        case maintainer = "530113860129259521"
        case automationDev = "1031520606434381824"
        case moderator = "431920836631592980"
        case core = "431919254372089857"
        
        static let elevatedPublicCommandsAccess: [Roles] = [
            .nitroBooster,
            .backer,
            .sponsor,
            .contributor,
            .maintainer,
            .automationDev,
            .moderator,
            .core,
        ]

        static let elevatedRestrictedCommandsAccess: [Roles] = [
            .contributor,
            .maintainer,
            .automationDev,
            .moderator,
            .core,
        ]

        static let elevatedRestrictedCommandsAccessSet: Set<RoleSnowflake> = Set([
            Roles.contributor,
            Roles.maintainer,
            Roles.moderator,
            Roles.automationDev,
            Roles.core,
        ].map(\.rawValue))

        static let moderators: Set<RoleSnowflake> = Set([
            Roles.automationDev,
            Roles.moderator,
            Roles.core
        ].map(\.rawValue))
    }
}
