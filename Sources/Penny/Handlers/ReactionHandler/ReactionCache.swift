import Logging
import DiscordBM
@preconcurrency import Collections
import Foundation

/// Cache for reactions-related stuff.
actor ReactionCache {

    struct GivenReactionCoinID: Sendable, Codable, Hashable {
        var senderID: UserSnowflake
        var authorOfMessageWithID: MessageSnowflake
        var emoji: Emoji
        var reactionKind: Gateway.ReactionKind
    }

    struct ChannelThanksMessage: Sendable, Codable {
        var pennyResponseMessageId: MessageSnowflake
        var senderUsers: OrderedSet<String>
        var totalCoinCount: Int

        static func `for`(_ pennyResponseMessageId: MessageSnowflake) -> Self {
            Self(
                pennyResponseMessageId: pennyResponseMessageId,
                senderUsers: [],
                totalCoinCount: 0
            )
        }
    }

    struct ChannelForcedThanksMessage: Sendable, Codable {
        var originalChannelId: ChannelSnowflake
        var pennyResponseMessageId: MessageSnowflake
        var senderUsers: OrderedSet<String>
        var totalCoinCount: Int
    }

    struct Storage: Sendable, Codable {
        /// `Set<[SenderID, MessageID]>`
        var givenCoins: OrderedSet<GivenReactionCoinID> = [] {
            didSet {
                if givenCoins.count > 200 {
                    givenCoins.removeFirst()
                }
            }
        }
        /// `[[ChannelSnowflake, Receiver-MessageSnowflake]: ChannelThanksMessage]`
        var normalThanksMessages = OrderedDictionary<[AnySnowflake], ChannelThanksMessage>() {
            didSet {
                if forcedInThanksChannelMessages.count > 200 {
                    forcedInThanksChannelMessages.removeFirst()
                }
            }
        }
        /// `[ReceiverMessageID: ChannelForcedThanksMessage]`
        var forcedInThanksChannelMessages = OrderedDictionary<MessageSnowflake, ChannelForcedThanksMessage>() {
            didSet {
                if forcedInThanksChannelMessages.count > 200 {
                    forcedInThanksChannelMessages.removeFirst()
                }
            }
        }
    }

    private var storage = Storage()
    let logger = Logger(label: "ReactionCache")

    init() { }

    /// This is to prevent spams. In case someone removes their reaction and
    /// reacts again, we should not give coins to message's author anymore.
    func canGiveCoin(
        fromSender senderId: UserSnowflake,
        toAuthorOfMessage messageId: MessageSnowflake,
        emoji: Emoji,
        reactionKind: Gateway.ReactionKind
    ) -> Bool {
        let givenReactionCoinID = GivenReactionCoinID(
            senderID: senderId,
            authorOfMessageWithID: messageId,
            emoji: emoji,
            reactionKind: reactionKind
        )
        return storage.givenCoins.append(givenReactionCoinID).inserted
    }

    /// Message have been created within last week,
    /// or we don't send a thanks response for it so it's less spammy.
    /// Also message author must not be a bot.
    func messageCanBeRespondedTo(
        channelId: ChannelSnowflake,
        messageId: MessageSnowflake,
        context: HandlerContext
    ) async -> Bool {
        guard let message = await self.getMessage(
            channelId: channelId,
            messageId: messageId,
            discordService: context.services.discordService
        ) else {
            return false
        }
        if message.author?.bot ?? false { return false }

        let calendar = Calendar.utc
        let now = Date()
        guard let aWeekAgo = calendar.date(byAdding: .weekOfMonth, value: -1, to: now) else {
            logger.error("Could not find the past-week date", metadata: [
                "now": .stringConvertible(now.timeIntervalSince1970)
            ])
            return true
        }
        let inPastWeek = calendar.compare(
            message.timestamp.date,
            to: aWeekAgo,
            toGranularity: .minute
        ) == .orderedDescending

        return inPastWeek
    }

    func getMessage(
        channelId: ChannelSnowflake,
        messageId: MessageSnowflake,
        discordService: DiscordService
    ) async -> DiscordChannel.Message? {
        guard let message = await discordService.getPossiblyCachedChannelMessage(
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
            let previous = storage.forcedInThanksChannelMessages[receiverMessageId]
            var names = previous?.senderUsers ?? []
            names.append(senderName)
            let amount = (previous?.totalCoinCount ?? 0) + amount
            storage.forcedInThanksChannelMessages[receiverMessageId] = .init(
                originalChannelId: channelId,
                pennyResponseMessageId: responseMessageId,
                senderUsers: names,
                totalCoinCount: amount
            )
        } else {
            let id = [AnySnowflake(channelId), AnySnowflake(receiverMessageId)]
            var item = storage.normalThanksMessages[id] ?? .for(responseMessageId)
            item.senderUsers.append(senderName)
            item.totalCoinCount += amount
            storage.normalThanksMessages[id] = item
        }
    }

    enum MessageToEditResponse {
        case normal(ChannelThanksMessage)
        case forcedInThanksChannel(ChannelForcedThanksMessage)
    }

    func messageToEditIfAvailable(
        in channelId: ChannelSnowflake,
        receiverMessageId: MessageSnowflake
    ) -> MessageToEditResponse? {
        if let existing = storage.forcedInThanksChannelMessages[receiverMessageId] {
            return .forcedInThanksChannel(existing)
        } else if let existing = storage.normalThanksMessages[
           [AnySnowflake(channelId), AnySnowflake(receiverMessageId)]
        ] {
            return .normal(existing)
        } else {
            return nil
        }
    }

    func consumeCachesStorageData(_ storage: Storage) {
        self.storage = storage
    }

    func getCachedDataForCachesStorage() -> Storage {
        self.storage
    }
}

private extension Calendar {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }()
}

// MARK: +Emoji
extension Emoji: Hashable {
    public static func == (lhs: Emoji, rhs: Emoji) -> Bool {
        switch (lhs.id, rhs.id) {
        case let (.some(id1), .some(id2)):
            return id1 == id2
        case (.none, .none):
            switch (lhs.name, rhs.name) {
            case let (.some(name1), .some(name2)):
                return name1 == name2
            default:
                Logger(label: "Emoji:Hashable.==").warning(
                    "Emojis didn't have id and name!", metadata: [
                        "lhs": "\(lhs)",
                        "rhs": "\(rhs)"
                    ]
                )
                return false
            }
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        if let id = self.id {
            hasher.combine(0)
            hasher.combine(id)
        } else if let name = self.name {
            hasher.combine(1)
            hasher.combine(name)
        } else {
            Logger(label: "Emoji:Hashable.hash(into:)").warning(
                "Emoji didn't have id and name!", metadata: [
                    "emoji": "\(self)"
                ]
            )
        }
    }
}
