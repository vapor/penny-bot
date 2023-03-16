import DiscordBM
import Logging
import PennyModels

private let coinSignEmojis = [
    "vaporlove",
    "🪙", "coin", // 'coin' is also Vapor server's coin
    "❤️", "💙", "💜", "🤍", "🤎", "🖤", "💛", "💚", "🧡",
    "💗", "💖", "💞", "❣️", "💓", "💘", "💝", "💕", "❤️‍🔥", "💟",
    "😍", "😻",
    "🙌", "🙌🏻", "🙌🏼", "🙌🏽", "🙌🏾", "🙌🏿",
    "🙏", "🙏🏻", "🙏🏼", "🙏🏽", "🙏🏾", "🙏🏿",
    "👌", "👌🏻", "👌🏼", "👌🏽", "👌🏾", "👌🏿",
]

struct ReactionHandler {
    let coinService: any CoinService
    var logger = Logger(label: "ReactionHandler")
    let event: Gateway.MessageReactionAdd
    private var cache: ReactionCache { .shared }
    
    init(coinService: any CoinService, event: Gateway.MessageReactionAdd) {
        self.coinService = coinService
        self.event = event
        self.logger[metadataKey: "event"] = "\(event)"
    }
    
    func handle() async {
        guard let member = event.member,
              let user = member.user,
              user.bot != true,
              let emoji = event.emoji.name,
              coinSignEmojis.contains(emoji),
              await cache.canGiveCoin(
                fromSender: user.id,
                toAuthorOfMessage: event.message_id
              ), let receiverId = await cache.getAuthorId(
                channelId: event.channel_id,
                messageId: event.message_id,
                logger: logger
              ), user.id != receiverId
        else { return }
        let sender = "<@\(user.id)>"
        let receiver = "<@\(receiverId)>"
        
        let coinRequest = CoinRequest.AddCoin(
            amount: 1,
            from: sender,
            receiver: receiver,
            source: .discord,
            reason: .userProvided
        )
        
        let response: CoinResponse
        do {
            response = try await self.coinService.postCoin(with: coinRequest)
        } catch {
            logger.report("Error when posting coins", error: error)
            await respond(
                with: "Oops. Something went wrong! Please try again later",
                senderName: nil,
                isAFailureMessage: true
            )
            return
        }
        
        let senderName = member.nick ?? user.username
        if let toEdit = await cache.messageToEditIfAvailable(
            in: event.channel_id,
            receiverMessageId: event.message_id
        ) {
            switch toEdit {
            case let .normal(pennyResponseMessageId, lastUsers):
                let names = lastUsers.joined(separator: ", ") + " & \(senderName)"
                let count = lastUsers.count + 1
                await editResponse(
                    messageId: pennyResponseMessageId,
                    with: "\(names) gave \(count) \(Constants.vaporCoinEmoji) to \(response.receiver), who now has \(response.coins) \(Constants.vaporCoinEmoji)!",
                    forcedInThanksChannel: false,
                    senderName: senderName
                )
            case let .forcedInThanksChannel(originalChannelId, pennyResponseMessageId, lastUsers):
                let link = "https://discord.com/channels/\(Constants.vaporGuildId)/\(originalChannelId)/\(event.message_id)\n"
                let names = lastUsers.joined(separator: ", ") + " & \(senderName)"
                let count = lastUsers.count + 1
                await editResponse(
                    messageId: pennyResponseMessageId,
                    with: link + "\(names) gave \(count) \(Constants.vaporCoinEmoji) to \(response.receiver), who now has \(response.coins) \(Constants.vaporCoinEmoji)!",
                    forcedInThanksChannel: true,
                    senderName: senderName
                )
            }
        } else {
            await respond(
                with: "\(senderName) gave a \(Constants.vaporCoinEmoji) to \(response.receiver), who now has \(response.coins) \(Constants.vaporCoinEmoji)!",
                senderName: senderName,
                isAFailureMessage: false
            )
        }
    }
    
    /// `senderName` only should be included if its not a error-response.
    private func respond(
        with response: String,
        senderName: String?,
        isAFailureMessage: Bool
    ) async {
        let apiResponse = await DiscordService.shared.sendThanksResponse(
            channelId: event.channel_id,
            replyingToMessageId: event.message_id,
            isAFailureMessage: isAFailureMessage,
            response: response
        )
        do {
            if let senderName,
               let decoded = try apiResponse?.decode() {
                /// If it's a thanks message that was sent to `#thanks` instead of the original
                /// channel, then we need to inform the cache.
                let sentToThanksChannelInstead = decoded.channel_id == Constants.thanksChannelId &&
                decoded.channel_id != event.channel_id
                await cache.didRespond(
                    originalChannelId: event.channel_id,
                    to: event.message_id,
                    with: decoded.id,
                    sentToThanksChannelInstead: sentToThanksChannelInstead,
                    senderName: senderName
                )
            }
        } catch {
            self.logger.report(
                "ReactionHandler could not decode message after send",
                response: apiResponse,
                metadata: ["error": "\(error)"]
            )
        }
    }
    
    /// `senderName` only should be included if its not a error-response.
    private func editResponse(
        messageId: String,
        with response: String,
        forcedInThanksChannel: Bool,
        senderName: String?
    ) async {
        let apiResponse = await DiscordService.shared.editMessage(
            messageId: messageId,
            channelId: forcedInThanksChannel ? Constants.thanksChannelId : event.channel_id,
            payload: .init(
                embeds: [.init(
                    description: response,
                    color: .vaporPurple
                )]
            )
        )
        do {
            if let senderName,
               let decoded = try apiResponse?.decode() {
                await cache.didRespond(
                    originalChannelId: event.channel_id,
                    to: event.message_id,
                    with: decoded.id,
                    sentToThanksChannelInstead: forcedInThanksChannel,
                    senderName: senderName
                )
            }
        } catch {
            self.logger.report(
                "ReactionHandler could not decode message after edit",
                response: apiResponse,
                metadata: ["error": "\(error)"]
            )
        }
    }
}

/// Cache for reactions-related stuff.
///
/// Optimally we would use some service like Redis to handle time-to-live
/// and disk-persistence for us, but this actor is more than enough at our scale.
actor ReactionCache {
    /// `[MessageID: AuthorID]`
    var cachedAuthorIds: [String: String] = [:]
    /// `Set<[SenderID, MessageID]>`
    var givenCoins: Set<[String]> = []
    /// `[ChannelID: (ReceiverMessageID, PennyResponseMessageID, [SenderUsers])]`.
    /// Channel's last message id if it is a thanks message to another message.
    var channelWithLastThanksMessage: [String: (String, String, [String])] = [:]
    /// `[ReceiverMessageID: (OriginalChannelID, PennyResponseMessageID, [SenderUsers])]`
    var thanksChannelForcedMessages: [String: (String, String, [String])] = [:]
    
    private init() { }
    
    static var shared = ReactionCache()
    
    /// Returns author of the message.
    fileprivate func getAuthorId(
        channelId: String,
        messageId: String,
        logger: Logger
    ) async -> String? {
        if let authorId = cachedAuthorIds[messageId] {
            return authorId
        } else {
            guard let message = await DiscordService.shared.getChannelMessage(
                channelId: channelId,
                messageId: messageId
            ) else {
                logger.error("ReactionCache could not find a message's author id", metadata: [
                    "channelId": .string(channelId),
                    "messageId": .string(messageId),
                ])
                return nil
            }
            if let authorId = message.author?.id {
                cachedAuthorIds[messageId] = authorId
                return authorId
            } else {
                logger.error("ReactionCache could not find a message's author id", metadata: [
                    "message": "\(message)"
                ])
                return nil
            }
        }
    }
    
    /// This is to prevent spams. In case someone removes their reaction and
    /// reacts again, we should not give coins to message's author anymore.
    func canGiveCoin(
        fromSender senderId: String,
        toAuthorOfMessage messageId: String
    ) -> Bool {
        givenCoins.insert([senderId, messageId]).inserted
    }
    
    fileprivate func didRespond(
        originalChannelId channelId: String,
        to receiverMessageId: String,
        with responseMessageId: String,
        sentToThanksChannelInstead: Bool,
        senderName: String
    ) {
        if sentToThanksChannelInstead {
            let names = (thanksChannelForcedMessages[receiverMessageId]?.2 ?? []) + [senderName]
            thanksChannelForcedMessages[receiverMessageId] = (channelId, responseMessageId, names)
        } else {
            let names = (channelWithLastThanksMessage[channelId]?.2 ?? []) + [senderName]
            channelWithLastThanksMessage[channelId] = (receiverMessageId, responseMessageId, names)
        }
    }
    
    enum MessageToEditResponse {
        case normal(pennyResponseMessageId: String, lastUsers: [String])
        case forcedInThanksChannel(
            originalChannelId: String,
            pennyResponseMessageId: String,
            lastUsers: [String]
        )
    }
    
    fileprivate func messageToEditIfAvailable(
        in channelId: String,
        receiverMessageId: String
    ) -> MessageToEditResponse? {
        if let existing = thanksChannelForcedMessages[receiverMessageId] {
            return .forcedInThanksChannel(
                originalChannelId: existing.0,
                pennyResponseMessageId: existing.1,
                lastUsers: existing.2
            )
        } else if let existing = channelWithLastThanksMessage[channelId] {
            if existing.0 == receiverMessageId {
                return .normal(pennyResponseMessageId: existing.1, lastUsers: existing.2)
            } else {
                channelWithLastThanksMessage[channelId] = nil
                return nil
            }
        } else {
            return nil
        }
    }
    
    /// If there is a new message in a channel, we need to invalidate the cache.
    /// Existence of a cached value for a channel implies that penny should
    /// edit its own last message.
    func invalidateCachesIfNeeded(event: Gateway.MessageCreate) {
        if let id = event.member?.user?.id ?? event.author?.id,
           id == Constants.botId {
            return
        } else {
            channelWithLastThanksMessage[event.channel_id] = nil
        }
    }
    
#if DEBUG
    static func _tests_reset() {
        shared = .init()
    }
#endif
}
