import DiscordBM

enum Constants {

    static let botDevUserID = UserSnowflake("290483761559240704")

    enum GitHub {
        /// The app-id of Penny.
        static let appID = 360798
        /// The installation-id of Penny for Vapor org.
        static let installationID = 39698047
    }

    enum Channels: ChannelSnowflake {
        case logs = "1067060193982156880"
        case issueAndPRs = "1123702585006768228"
        case release = "431926479752921098"

        var id: ChannelSnowflake {
            self.rawValue
        }
    }
}
