import DiscordBM

enum OAuthLambdaConstants {
    enum Channels: ChannelSnowflake {
        case logs = "1067060193982156880"
        
        var id: ChannelSnowflake {
            self.rawValue
        }
    }
}
