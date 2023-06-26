import Logging
import DiscordBM
import Collections
import Foundation

/// Cache for reactions-related stuff.
///
/// Optimally we would use some service like Redis to handle time-to-live
/// and disk-persistence for us, but this actor is more than enough at our scale.
actor ReactionCache {

    struct ChannelLastThanksMessage: Codable {
        var receiverMessageId: MessageSnowflake
        var pennyResponseMessageId: MessageSnowflake
        var senderUsers: [String]
        var totalCoinCount: Int
    }

    struct ChannelForcedThanksMessage: Codable {
        var originalChannelId: ChannelSnowflake
        var pennyResponseMessageId: MessageSnowflake
        var senderUsers: [String]
        var totalCoinCount: Int
    }

    struct Storage: Codable {
        /// `[MessageID: AuthorID]`
        var cachedAuthorIds: OrderedDictionary<MessageSnowflake, UserSnowflake> = [:] {
            didSet {
                /// To limit the amount of items to not leak memory
                /// and not explode the caches S3 bucket.
                if cachedAuthorIds.count > 200 {
                    cachedAuthorIds.removeLast()
                }
            }
        }
        /// `Set<[SenderID, MessageID]>`
        var givenCoins: OrderedSet<[AnySnowflake]> = [] {
            didSet {
                if givenCoins.count > 200 {
                    givenCoins.removeLast()
                }
            }
        }
        /// Channel's last message id if it is a thanks message to another message.
        var channelWithLastThanksMessage = [ChannelSnowflake: ChannelLastThanksMessage]()
        /// `[ReceiverMessageID: ChannelForcedThanksMessage]`
        var thanksChannelForcedMessages = OrderedDictionary<MessageSnowflake, ChannelForcedThanksMessage>() {
            didSet {
                if thanksChannelForcedMessages.count > 200 {
                    thanksChannelForcedMessages.removeLast()
                }
            }
        }
    }

    private var storage = Storage()
    let logger = Logger(label: "ReactionCache")

    private init() { }

    static var shared = ReactionCache()

    /// Returns author of the message.
    func getAuthorId(
        channelId: ChannelSnowflake,
        messageId: MessageSnowflake
    ) async -> UserSnowflake? {
        if let authorId = storage.cachedAuthorIds[messageId] {
            return authorId
        } else {
            guard let message = await self.getMessage(
                channelId: channelId,
                messageId: messageId
            ) else {
                return nil
            }
            if let authorId = message.author?.id {
                storage.cachedAuthorIds[messageId] = authorId
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
        storage.givenCoins.append([AnySnowflake(senderId), AnySnowflake(messageId)]).inserted
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

    func didRespond(
        originalChannelId channelId: ChannelSnowflake,
        to receiverMessageId: MessageSnowflake,
        with responseMessageId: MessageSnowflake,
        sentToThanksChannelInstead: Bool,
        amount: Int,
        senderName: String
    ) {
        if sentToThanksChannelInstead {
            let previous = storage.thanksChannelForcedMessages[receiverMessageId]
            let names = (previous?.senderUsers ?? []) + [senderName]
            let amount = (previous?.totalCoinCount ?? 0) + amount
            storage.thanksChannelForcedMessages[receiverMessageId] = .init(
                originalChannelId: channelId,
                pennyResponseMessageId: responseMessageId,
                senderUsers: names,
                totalCoinCount: amount
            )
        } else {
            let previous = storage.channelWithLastThanksMessage[channelId]
            let names = (previous?.senderUsers ?? []) + [senderName]
            let amount = (previous?.totalCoinCount ?? 0) + amount
            storage.channelWithLastThanksMessage[channelId] = .init(
                receiverMessageId: receiverMessageId,
                pennyResponseMessageId: responseMessageId,
                senderUsers: names,
                totalCoinCount: amount
            )
        }
    }

    enum MessageToEditResponse {
        case normal(ChannelLastThanksMessage)
        case forcedInThanksChannel(ChannelForcedThanksMessage)
    }

    func messageToEditIfAvailable(
        in channelId: ChannelSnowflake,
        receiverMessageId: MessageSnowflake
    ) -> MessageToEditResponse? {
        if let existing = storage.thanksChannelForcedMessages[receiverMessageId] {
            return .forcedInThanksChannel(existing)
        } else if let existing = storage.channelWithLastThanksMessage[channelId] {
            if existing.receiverMessageId == receiverMessageId {
                return .normal(existing)
            } else {
                storage.channelWithLastThanksMessage[channelId] = nil
                return nil
            }
        } else {
            return nil
        }
    }

    func fromCacheStorageData(_ storage: Storage) {
        self.storage = storage
    }

    func toCacheStorageData() -> Storage {
        self.storage
    }

#if DEBUG
    static func _tests_reset() {
        shared = .init()
    }
#endif
}
