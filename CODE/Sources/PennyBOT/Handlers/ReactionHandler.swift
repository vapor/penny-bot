import DiscordBM
import Logging
import PennyModels
import Foundation

private let coinSignEmojis = [
    "vaporlove",
    "🪙", "coin", // 'coin' is also Vapor server's coin
    "❤️", "💙", "💜", "🤍", "🤎", "🖤", "💛", "💚", "🧡",
    "💗", "💖", "💞", "❣️", "💓", "💘", "💝", "💕", "❤️‍🔥", "💟",
    "😍", "😻",
    "🚀",
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
                messageId: event.message_id
              ), user.id != receiverId
        else { return }
        let sender = "<@\(user.id)>"
        let receiver = "<@\(receiverId)>"

        /// Super reactions give more coins, otherwise only 1 coin
        let amount = event.type == .super ? 3 : 1

        let coinRequest = CoinRequest.AddCoin(
            amount: amount,
            from: sender,
            receiver: receiver,
            source: .discord,
            reason: .userProvided
        )
        
        var response: CoinResponse?
        do {
            response = try await self.coinService.postCoin(with: coinRequest)
        } catch {
            logger.report("Error when posting coins", error: error)
            response = nil
        }
        
        guard await cache.messageCanBeRespondedTo(
            channelId: event.channel_id,
            messageId: event.message_id
        ) else { return }
        
        guard let response = response else {
            await respond(
                with: "Oops. Something went wrong! Please try again later",
                amount: amount,
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
            case let .normal(info):
                let names = info.senderUsers.joined(separator: ", ") + " & \(senderName)"
                let count = info.totalCoinCount + amount
                await editResponse(
                    messageId: info.pennyResponseMessageId,
                    with: "\(names) gave \(count) \(Constants.vaporCoinEmoji) to \(response.receiver), who now has \(response.coins) \(Constants.vaporCoinEmoji)!",
                    forcedInThanksChannel: false,
                    amount: amount,
                    senderName: senderName
                )
            case let .forcedInThanksChannel(info):
                let link = "https://discord.com/channels/\(Constants.vaporGuildId)/\(info.originalChannelId)/\(event.message_id)"
                let names = info.senderUsers.joined(separator: ", ") + " & \(senderName)"
                let count = info.totalCoinCount + amount
                await editResponse(
                    messageId: info.pennyResponseMessageId,
                    with: "\(names) gave \(count) \(Constants.vaporCoinEmoji) to \(response.receiver), who now has \(response.coins) \(Constants.vaporCoinEmoji)! (\(link))",
                    forcedInThanksChannel: true,
                    amount: amount,
                    senderName: senderName
                )
            }
        } else {
            let coinCountDescription = amount == 1 ?
            "a \(Constants.vaporCoinEmoji)" :
            "\(amount) \(Constants.vaporCoinEmoji)"
            await respond(
                with: "\(senderName) gave \(coinCountDescription) to \(response.receiver), who now has \(response.coins) \(Constants.vaporCoinEmoji)!",
                amount: amount,
                senderName: senderName,
                isAFailureMessage: false
            )
        }
    }
    
    /// `senderName` only should be included if its not a error-response.
    private func respond(
        with response: String,
        amount: Int,
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
                    amount: amount,
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
        messageId: MessageSnowflake,
        with response: String,
        forcedInThanksChannel: Bool,
        amount: Int,
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
                    amount: amount,
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
    private var cachedAuthorIds: [MessageSnowflake: UserSnowflake] = [:]
    /// `Set<[SenderID, MessageID]>`
    private var givenCoins: Set<[AnySnowflake]> = []
    /// Channel's last message id if it is a thanks message to another message.
    private var channelWithLastThanksMessage: [
        ChannelSnowflake: ChannelLastThanksMessage] = [:]
    /// `[ReceiverMessageID: ChannelForcedThanksMessage]`
    private var thanksChannelForcedMessages: [
        MessageSnowflake: ChannelForcedThanksMessage] = [:]
    let logger = Logger(label: "ReactionCache")
    
    private init() { }
    
    static var shared = ReactionCache()
    
    /// Returns author of the message.
    fileprivate func getAuthorId(
        channelId: ChannelSnowflake,
        messageId: MessageSnowflake
    ) async -> UserSnowflake? {
        if let authorId = cachedAuthorIds[messageId] {
            return authorId
        } else {
            guard let message = await self.getMessage(
                channelId: channelId,
                messageId: messageId
            ) else {
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
        fromSender senderId: UserSnowflake,
        toAuthorOfMessage messageId: MessageSnowflake
    ) -> Bool {
        givenCoins.insert([AnySnowflake(senderId), AnySnowflake(messageId)]).inserted
    }
    
    /// Message have been created within last week,
    /// or we don't send a thanks response for it so it's less spammy.
    /// Also message author must not be a bot.
    func messageCanBeRespondedTo(
        channelId: ChannelSnowflake,
        messageId: MessageSnowflake
    ) async -> Bool {
        guard let message = await self.getMessage(channelId: channelId, messageId: messageId) else {
            return false
        }
        let inPastWeek = message.timestamp.date > Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let isNotBot = message.author?.bot != true
        return inPastWeek && isNotBot
    }
    
    func getMessage(
        channelId: ChannelSnowflake,
        messageId: MessageSnowflake
    ) async -> DiscordChannel.Message? {
        guard let message = await DiscordService.shared.getPossiblyCachedChannelMessage(
            channelId: channelId,
            messageId: messageId
        ) else {
            logger.error("ReactionCache could not find a message's author id", metadata: [
                "channelId": .stringConvertible(channelId),
                "messageId": .stringConvertible(messageId),
            ])
            return nil
        }
        return message
    }
    
    fileprivate func didRespond(
        originalChannelId channelId: ChannelSnowflake,
        to receiverMessageId: MessageSnowflake,
        with responseMessageId: MessageSnowflake,
        sentToThanksChannelInstead: Bool,
        amount: Int,
        senderName: String
    ) {
        if sentToThanksChannelInstead {
            let previous = thanksChannelForcedMessages[receiverMessageId]
            let names = (previous?.senderUsers ?? []) + [senderName]
            let amount = (previous?.totalCoinCount ?? 0) + amount
            thanksChannelForcedMessages[receiverMessageId] = .init(
                originalChannelId: channelId,
                pennyResponseMessageId: responseMessageId,
                senderUsers: names,
                totalCoinCount: amount
            )
        } else {
            let previous = channelWithLastThanksMessage[channelId]
            let names = (previous?.senderUsers ?? []) + [senderName]
            let amount = (previous?.totalCoinCount ?? 0) + amount
            channelWithLastThanksMessage[channelId] = .init(
                receiverMessageId: receiverMessageId,
                pennyResponseMessageId: responseMessageId,
                senderUsers: names,
                totalCoinCount: amount
            )
        }
    }
    
    fileprivate enum MessageToEditResponse {
        case normal(ChannelLastThanksMessage)
        case forcedInThanksChannel(ChannelForcedThanksMessage)
    }
    
    fileprivate func messageToEditIfAvailable(
        in channelId: ChannelSnowflake,
        receiverMessageId: MessageSnowflake
    ) -> MessageToEditResponse? {
        if let existing = thanksChannelForcedMessages[receiverMessageId] {
            return .forcedInThanksChannel(existing)
        } else if let existing = channelWithLastThanksMessage[channelId] {
            if existing.receiverMessageId == receiverMessageId {
                return .normal(existing)
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
           id.value == Constants.botId {
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

private struct ChannelLastThanksMessage {
    var receiverMessageId: MessageSnowflake
    var pennyResponseMessageId: MessageSnowflake
    var senderUsers: [String]
    var totalCoinCount: Int
}

private struct ChannelForcedThanksMessage {
    var originalChannelId: ChannelSnowflake
    var pennyResponseMessageId: MessageSnowflake
    var senderUsers: [String]
    var totalCoinCount: Int
}
