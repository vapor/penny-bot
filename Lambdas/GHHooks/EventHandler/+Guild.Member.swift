import DiscordBM

extension Guild.Member {
    var uiName: String? {
        self.nick ?? self.user?.global_name ?? self.user?.username
    }

    var uiAvatarURL: String? {
        guard let user = self.user else {
            return nil
        }
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
        } else {
            return nil
        }
    }
}
