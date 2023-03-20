import DiscordBM
import Logging

actor DiscordService {
    
    private var discordClient: (any DiscordClient)!
    private var cache: DiscordCache!
    private var logger = Logger(label: "DiscordService")
    /// `[UserDiscordID: DMChannelID]`
    private var dmChannels: [String: String] = [:]
    private var usersAlreadyWarnedAboutClosedDMS: Set<String> = []
    private var vaporGuild: Gateway.GuildCreate? {
        get async {
            guard let guild = await cache.guilds[Constants.vaporGuildId] else {
                let guilds = await cache.guilds
                logger.error("Cannot get cached vapor guild", metadata: ["guilds": "\(guilds)"])
                return nil
            }
            
            /// This could cause problems so we need to somehow keep an eye on it.
            /// `Array.count` is O(1) so this is fine.
            let memberCount = guild.members.count
            if memberCount < 1_000 {
                logger.error("Vapor guild only has \(memberCount) members?!", metadata: [
                    "guild": "\(guild)"
                ])
            }
            
            return guild
        }
    }
    
    private init () { }
    
    static let shared = DiscordService()
    
    func initialize(discordClient: any DiscordClient, cache: DiscordCache) {
        self.discordClient = discordClient
        self.cache = cache
    }
    
    func sendDM(userId: String, payload: RequestBody.CreateMessage) async {
        guard let dmChannelId = await getDMChannelId(userId: userId) else { return }
        
        do {
            let response = try await discordClient.createMessage(
                channelId: dmChannelId,
                payload: payload
            )
            
            switch response.decodeError() {
            case let .jsonError(jsonError)
                where jsonError.code == .cannotSendMessagesToThisUser:
                /// Try to let them know Penny can't DM them.
                if usersAlreadyWarnedAboutClosedDMS.insert(userId).inserted {
                    
                    logger.warning("Could not send DM, will try to let them know", metadata: [
                        "userId": .string(userId),
                        "dmChannelId": .string(dmChannelId),
                        "payload": "\(payload)",
                        "jsonError": "\(jsonError)"
                    ])
                    
                    Task {
                        let userMention = DiscordUtils.userMention(id: userId)
                        let message = "I tried to DM you but couldn't. Please open your DMs to me. You can allow Vapor server members to DM you by going into your `Server Settings` (tap Vapor server name), then choosing `Allow Direct Messages`. On Desktop, this option is under the `Privacy Settings` menu."
                        /// Make it wait 1 to 10 minutes so it's not too
                        /// obvious what message the user was DMed about.
                        try await Task.sleep(for: .seconds(.random(in: 60...600)))
                        await self.sendMessage(
                            channelId: Constants.thanksChannelId,
                            payload: .init(
                                content: userMention,
                                embeds: [.init(description: message, color: .vaporPurple)])
                        )
                    }
                }
            case .jsonError, .badStatusCode:
                logger.report("Couldn't send DM", response: response, metadata: [
                    "userId": .string(userId),
                    "dmChannelId": .string(dmChannelId),
                    "payload": "\(payload)"
                ])
            case .none: break
            }
        } catch {
            logger.report("Couldn't send DM", error: error, metadata: [
                "userId": .string(userId),
                "dmChannelId": .string(dmChannelId),
                "payload": "\(payload)"
            ])
        }
    }
    
    private func getDMChannelId(userId: String) async -> String? {
        if let existing = dmChannels[userId] {
            return existing
        } else {
            do {
                let dmChannel = try await discordClient.createDM(recipient_id: userId).decode()
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
        channelId: String,
        payload: RequestBody.CreateMessage
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
    @discardableResult
    func sendThanksResponse(
        channelId: String,
        replyingToMessageId messageId: String,
        isAFailureMessage: Bool,
        response: String
    ) async -> DiscordClientResponse<DiscordChannel.Message>? {
        let hasPermissionToSend = await vaporGuild?.userHasPermissions(
            userId: Constants.botId,
            channelId: channelId,
            permissions: [.sendMessages]
        ) == true
        if hasPermissionToSend {
            return await self.sendMessage(
                channelId: channelId,
                payload: .init(
                    embeds: [.init(
                        description: response,
                        color: .vaporPurple
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
            if isAFailureMessage { return nil }
            let link = "https://discord.com/channels/\(Constants.vaporGuildId)/\(channelId)/\(messageId)\n"
            return await self.sendMessage(
                channelId: Constants.thanksChannelId,
                payload: .init(
                    embeds: [.init(
                        description: link + response,
                        color: .vaporPurple
                    )]
                )
            )
        }
    }
    
    @discardableResult
    func editMessage(
        messageId: String,
        channelId: String,
        payload: RequestBody.EditMessage
    ) async -> DiscordClientResponse<DiscordChannel.Message>? {
        do {
            let response = try await discordClient.editMessage(
                channelId: channelId,
                messageId: messageId,
                payload: payload
            )
            try response.guardSuccess()
            return response
        } catch {
            logger.report("Couldn't edit a message", error: error, metadata: [
                "messageId": .string(messageId),
                "channelId": .string(channelId),
                "payload": "\(payload)"
            ])
            return nil
        }
    }
    
    /// Returns whether or not the response has been successfully sent.
    @discardableResult
    func respondToInteraction(
        id: String,
        token: String,
        payload: RequestBody.InteractionResponse
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
                "id": .string(id),
                "token": .string(token),
                "payload": "\(payload)"
            ])
            return false
        }
    }
    
    func editInteraction(
        token: String,
        payload: RequestBody.InteractionResponse.CallbackData
    ) async {
        do {
            try await discordClient.editInteractionResponse(
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
    
    func overwriteCommands(_ commands: [RequestBody.ApplicationCommandCreate]) async {
        do {
            try await discordClient
                .bulkOverwriteGlobalApplicationCommands(payload: commands)
                .guardSuccess()
        } catch {
            logger.report("Couldn't overwrite application commands", error: error, metadata: [
                "commands": "\(commands)"
            ])
        }
    }
    
    func getCommands() async -> [ApplicationCommand] {
        do {
            return try await discordClient.getGlobalApplicationCommands().decode()
        } catch {
            logger.report("Couldn't get application commands", error: error)
            return []
        }
    }
    
    func getChannelMessage(
        channelId: String,
        messageId: String
    ) async -> Gateway.MessageCreate? {
        do {
            return try await discordClient.getChannelMessage(
                channelId: channelId,
                messageId: messageId
            ).decode()
        } catch {
            logger.report("Couldn't get channel message", error: error, metadata: [
                "channelId": .string(channelId),
                "messageId": .string(messageId)
            ])
            return nil
        }
    }
    
    func userHasReadAccess(userId: String, channelId: String) async -> Bool {
        guard let guild = await self.vaporGuild else { return false }
        return guild.userHasPermissions(
            userId: userId,
            channelId: channelId,
            permissions: [.readMessageHistory]
        )
    }
    
    func memberHasRolesForElevatedPublicCommandsAccess(member: Guild.Member) -> Bool {
        Constants.Roles.elevatedPublicCommandsAccess.contains(where: {
            member.roles.contains($0.rawValue)
        })
    }
}
