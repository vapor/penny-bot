import DiscordBM

extension Guild.Member {
    var uiName: String? {
        self.nick ??
        self.user?.username ??
        self.user?.global_name
    }

    var uiAvatarCDNEndpoint: CDNEndpoint? {
        if let user = self.user {
            if let avatar = self.avatar {
                return CDNEndpoint.guildMemberAvatar(
                    guildId: Constants.guildID,
                    userId: user.id,
                    avatar: avatar
                )
            } else if let avatar = user.avatar {
                return CDNEndpoint.userAvatar(
                    userId: user.id,
                    avatar: avatar
                )
            }
        }

        return nil
    }
}
