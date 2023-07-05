import DiscordBM

enum Constants {
    enum Channels: ChannelSnowflake {
        case logs = "1067060193982156880"
        case issueAndPRs = "1123702585006768228"
        case release = "431926479752921098"

        var id: ChannelSnowflake {
            self.rawValue
        }
    }
}
