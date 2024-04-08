import DiscordBM
import Logging

actor DiscordService {

    enum Error: Swift.Error {
        case cantGetGuild
        case cantFindChannel
    }
    
    private let discordClient: any DiscordClient
    private let cache: DiscordCache
    private var logger = Logger(label: "DiscordService")
    private var dmChannels: [UserSnowflake: ChannelSnowflake] = [:]
    private var usersAlreadyWarnedAboutClosedDMS: Set<UserSnowflake> = []
    private var vaporGuild: Gateway.GuildCreate {
        get async throws {
            guard let guild = await cache.guilds[Constants.vaporGuildId] else {
                let guilds = await cache.guilds
                logger.error("Cannot get cached vapor guild", metadata: ["guilds": "\(guilds)"])
                throw Error.cantGetGuild
            }
            
            /// This could cause problems so we need to somehow keep an eye on it.
            /// `Array.count` is O(1) so this is fine.
            if guild.members.count < 1_000 {
                logger.critical("Vapor guild only has \(guild.members.count) members?!", metadata: [
                    "guild": "\(guild)"
                ])
            }
            
            return guild
        }
    }
    
    init(discordClient: any DiscordClient, cache: DiscordCache) {
        self.discordClient = discordClient
        self.cache = cache
    }
    
    func sendDM(userId: UserSnowflake, payload: Payloads.CreateMessage) async {
        guard let dmChannelId = await getDMChannelId(userId: userId) else { return }
        
        do {
            let response = try await discordClient.createMessage(
                channelId: dmChannelId,
                payload: payload
            )
            
            switch response.asError() {
            case let .jsonError(jsonError)
                where jsonError.code == .cannotSendMessagesToThisUser:
                /// Try to let them know Penny can't DM them.
                if usersAlreadyWarnedAboutClosedDMS.insert(userId).inserted {
                    
                    logger.warning("Could not send DM, will try to let them know", metadata: [
                        "userId": .stringConvertible(userId),
                        "dmChannelId": .stringConvertible(dmChannelId),
                        "payload": "\(payload)",
                        "jsonError": "\(jsonError)"
                    ])
                    
                    Task {
                        let userMention = DiscordUtils.mention(id: userId)
                        /// Make it wait 1 to 10 minutes so it's not too
                        /// obvious what message the user was DMed about.
                        try await Task.sleep(for: .seconds(.random(in: 60...600)))
                        await self.sendMessage(
                            channelId: Constants.Channels.thanks.id,
                            payload: .init(
                                content: userMention,
                                embeds: [.init(
                                    description: """
                                    I tried to DM you but couldn't. Please open your DMs to me.

                                    You can allow Vapor server members to DM you by going into your `Server Settings` (tap Vapor server name), then choosing `Allow Direct Messages`.

                                    On Desktop, this option is under the `Privacy Settings` menu.
                                    """,
                                    color: .purple
                                )]
                            )
                        )
                    }
                }
            case .jsonError, .badStatusCode:
                logger.report("Couldn't send DM", response: response, metadata: [
                    "userId": .stringConvertible(userId),
                    "dmChannelId": .stringConvertible(dmChannelId),
                    "payload": "\(payload)"
                ])
            case .none: break
            }
        } catch {
            logger.report("Couldn't send DM", error: error, metadata: [
                "userId": .stringConvertible(userId),
                "dmChannelId": .stringConvertible(dmChannelId),
                "payload": "\(payload)"
            ])
        }
    }
    
    private func getDMChannelId(userId: UserSnowflake) async -> ChannelSnowflake? {
        if let existing = dmChannels[userId] {
            return existing
        } else {
            do {
                let dmChannel = try await discordClient.createDm(
                    payload: .init(recipient_id: userId)
                ).decode()
                dmChannels[userId] = dmChannel.id
                return dmChannel.id
            } catch {
                logger.error("Couldn't get DM channel for user", metadata: ["userId": "\(userId)"])
                return nil
            }
        }
    }
    
    @discardableResult
    func sendMessage(
        channelId: ChannelSnowflake,
        payload: Payloads.CreateMessage
    ) async -> DiscordClientResponse<DiscordChannel.Message>? {
        do {
            let response = try await discordClient.createMessage(
                channelId: channelId,
                payload: payload
            )
            try response.guardSuccess()
            return response
        } catch {
            logger.report("Couldn't send a message", error: error, metadata: [
                "channelId": "\(channelId)",
                "payload": "\(payload)"
            ])
            return nil
        }
    }
    
    /// Sends thanks response to the specified channel if Penny has the required permissions,
    /// otherwise sends to the `#thanks` channel.
    /// - Parameters:
    ///   - isFailureMessage: If this message is informing users of a failure
    ///   while performing the main action.
    @discardableResult
    func sendThanksResponse(
        channelId: ChannelSnowflake,
        replyingToMessageId messageId: MessageSnowflake,
        isFailureMessage: Bool,
        content: String? = nil,
        response: String
    ) async -> DiscordClientResponse<DiscordChannel.Message>? {
        var canSendToChannel = true

        /// If the channel is in the deny-list, then can't send the response to the channel directly.
        canSendToChannel = !Constants.Channels.thanksResponseDenyList.contains(channelId)

        /// If it still can send the message, check for permissions too.
        if canSendToChannel {
            do {
                canSendToChannel = try await vaporGuild.userHasPermissions(
                    userId: Constants.botId,
                    channelId: channelId,
                    permissions: [.sendMessages]
                )
            } catch {
                logger.report("Can't resolve user permissions", error: error)
                return nil
            }
        }

        if canSendToChannel {
            return await self.sendMessage(
                channelId: channelId,
                payload: .init(
                    content: content,
                    embeds: [.init(
                        description: response,
                        color: .purple
                    )],
                    message_reference: .init(
                        message_id: messageId,
                        channel_id: channelId,
                        guild_id: Constants.vaporGuildId,
                        fail_if_not_exists: false
                    )
                )
            )
        } else {
            /// Don't report failures to users, in this case.
            if isFailureMessage {
                logger.debug("Won't report a failure to users")
                return nil
            }
            let link = "https://discord.com/channels/\(Constants.vaporGuildId.rawValue)/\(channelId.rawValue)/\(messageId.rawValue)"
            return await self.sendMessage(
                channelId: Constants.Channels.thanks.id,
                payload: .init(
                    content: content,
                    embeds: [.init(
                        description: "\(response) (\(link))",
                        color: .purple
                    )]
                )
            )
        }
    }
    
    @discardableResult
    func editMessage(
        messageId: MessageSnowflake,
        channelId: ChannelSnowflake,
        payload: Payloads.EditMessage
    ) async -> DiscordClientResponse<DiscordChannel.Message>? {
        do {
            let response = try await discordClient.updateMessage(
                channelId: channelId,
                messageId: messageId,
                payload: payload
            )
            try response.guardSuccess()
            return response
        } catch {
            logger.report("Couldn't edit a message", error: error, metadata: [
                "messageId": .stringConvertible(messageId),
                "channelId": .stringConvertible(channelId),
                "payload": "\(payload)"
            ])
            return nil
        }
    }
    
    /// Returns whether or not the response has been successfully sent.
    @discardableResult
    func respondToInteraction(
        id: InteractionSnowflake,
        token: String,
        payload: Payloads.InteractionResponse
    ) async -> Bool {
        do {
            try await discordClient.createInteractionResponse(
                id: id,
                token: token,
                payload: payload
            ).guardSuccess()
            return true
        } catch {
            logger.report("Couldn't send interaction response", error: error, metadata: [
                "id": .stringConvertible(id),
                "token": .string(token),
                "payload": "\(payload)"
            ])
            return false
        }
    }
    
    func editInteraction(
        token: String,
        payload: Payloads.EditWebhookMessage
    ) async {
        do {
            try await discordClient.updateOriginalInteractionResponse(
                token: token,
                payload: payload
            ).guardSuccess()
        } catch {
            logger.report("Couldn't send interaction edit", error: error, metadata: [
                "token": .string(token),
                "payload": "\(payload)"
            ])
        }
    }
    
    func overwriteCommands(_ commands: [Payloads.ApplicationCommandCreate]) async {
        do {
            try await discordClient
                .bulkSetApplicationCommands(payload: commands)
                .guardSuccess()
        } catch {
            logger.report("Couldn't overwrite application commands", error: error, metadata: [
                "commands": "\(commands)"
            ])
        }
    }
    
    func getCommands() async -> [ApplicationCommand] {
        do {
            return try await discordClient.listApplicationCommands().decode()
        } catch {
            logger.report("Couldn't get application commands", error: error)
            return []
        }
    }

    /// Returns a non-empty array of messages which includes all edits as well, for a deleted message. Otherwise nil.
    func getDeletedMessageWithEditions(
        id: MessageSnowflake,
        channelId: ChannelSnowflake
    ) async -> [Gateway.MessageCreate]? {
        guard let messages = await cache.deletedMessages[channelId]?[id],
              !messages.isEmpty else {
            return nil
        }
        return messages
    }

    /// Returns a non-empty array of messages which includes all edits as well, for a deleted message. Otherwise nil.
    func getDeletedMessageWithEditions(id: MessageSnowflake) async -> [Gateway.MessageCreate]? {
        for (_, messagesDict) in await cache.deletedMessages {
            guard let messages = messagesDict[id],
                  !messages.isEmpty else {
                continue
            }
            return messages
        }
        return nil
    }

    func getChannelMessage(
        channelId: ChannelSnowflake,
        messageId: MessageSnowflake
    ) async -> AnyMessage? {
        if let fromCache = await cache.messages[channelId]?
            .first(where: { $0.id == messageId }) {
            return .init(fromCache)
        }
        do {
            let message = try await discordClient.getMessage(
                channelId: channelId,
                messageId: messageId
            ).decode()
            return .init(message)
        } catch {
            logger.report("Couldn't get channel message", error: error, metadata: [
                "channelId": .string(channelId.rawValue),
                "messageId": .string(messageId.rawValue)
            ])
            return nil
        }
    }

    func createThreadFromMessage(
        channelId: ChannelSnowflake,
        messageId: MessageSnowflake,
        payload: Payloads.CreateThreadFromMessage
    ) async {
        do {
            try await discordClient.createThreadFromMessage(
                channelId: channelId,
                messageId: messageId,
                payload: payload
            ).guardSuccess()
        } catch {
            logger.report("Couldn't create thread from message", error: error, metadata: [
                "channelId": .stringConvertible(channelId),
                "messageId": .stringConvertible(messageId),
                "payload": .string("\(payload)")
            ])
        }
    }

    func crosspostMessage(
        channelId: ChannelSnowflake,
        messageId: MessageSnowflake
    ) async {
        do {
            try await discordClient.crosspostMessage(
                channelId: channelId,
                messageId: messageId
            ).guardSuccess()
        } catch {
            logger.report("Couldn't crosspost message", error: error, metadata: [
                "channelId": .stringConvertible(channelId),
                "messageId": .stringConvertible(messageId),
            ])
        }
    }
    
    func userHasReadAccess(
        userId: UserSnowflake,
        channelId: ChannelSnowflake
    ) async throws -> Bool {
        try await self.vaporGuild.userHasPermissions(
            userId: userId,
            channelId: channelId,
            permissions: [.viewChannel, .readMessageHistory]
        )
    }

    func userIsModerator(userId: UserSnowflake) async throws -> Bool {
        try await self.vaporGuild.userHasGuildPermission(
            userId: userId,
            permission: .moderateMembers
        )
    }

    func memberHasRolesForElevatedPublicCommandsAccess(member: Guild.Member) -> Bool {
        Constants.Roles.elevatedPublicCommandsAccess.contains(where: {
            member.roles.contains($0.rawValue)
        })
    }

    func memberHasRolesForElevatedRestrictedCommandsAccess(member: Guild.Member) -> Bool {
        !Set(member.roles)
            .intersection(Constants.Roles.elevatedRestrictedCommandsAccessSet)
            .isEmpty
    }
}
