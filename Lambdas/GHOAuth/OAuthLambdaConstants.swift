import DiscordBM

enum Constants {
    enum Channels: ChannelSnowflake {
        case logs = "1067060193982156880"
        
        var id: ChannelSnowflake {
            self.rawValue
        }
    }
}
