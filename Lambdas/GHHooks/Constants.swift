import DiscordBM

enum Constants {

    static let guildID: GuildSnowflake = "431917998102675485"
    static let botDevUserID: UserSnowflake = "290483761559240704"

    enum GitHub {
        /// The user id of Penny.
        static let userID = 139_480_971
        /// The app-id of Penny.
        static let appID = 360798
        /// The installation-id of Penny for Vapor org.
        static let installationID = 39_698_047
    }

    enum Channels: ChannelSnowflake, CaseIterable {
        case logs = "1067060193982156880"
        case issueAndPRs = "1123702585006768228"
        case release = "431926479752921098"
        case thanks = "443074453719744522"

        var id: ChannelSnowflake {
            self.rawValue
        }
    }

    enum Roles: RoleSnowflake {
        case core = "431919254372089857"

        var id: RoleSnowflake {
            self.rawValue
        }
    }

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
}
