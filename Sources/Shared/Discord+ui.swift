import DiscordBM

extension Guild.Member {
    package var uiName: String? {
        self.nick ??
        self.user?.global_name ??
        self.user?.username
    }

    package var uiAvatarURL: String? {
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

extension Guild.PartialMember {
    package var uiName: String? {
        self.nick ??
        self.user?.global_name ??
        self.user?.username
    }

    package var uiAvatarURL: String? {
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

extension DiscordUser {
    package var uiName: String {
        self.global_name ??
        self.username
    }

    package var uiAvatarURL: String? {
        self.avatar.map {
            CDNEndpoint.userAvatar(
                userId: self.id,
                avatar: $0
            ).url
        }
    }
}
