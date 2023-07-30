import DiscordBM

extension Guild.Member {
    var uiName: String? {
        self.nick ??
        self.user?.username ??
        self.user?.global_name
    }

    var uiAvatarURL: String? {
        if let user = self.user {
            if let avatar = self.avatar {
                return CDNEndpoint.guildMemberAvatar(
                    guildId: Constants.guildID,
                    userId: user.id,
                    avatar: avatar
                ).url
            } else if let avatar = user.avatar {
                return CDNEndpoint.userAvatar(
                    userId: user.id,
                    avatar: avatar
                ).url
            }
        }

        return nil
    }
}
