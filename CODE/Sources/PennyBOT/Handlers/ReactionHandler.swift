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
    let discordClient: any DiscordClient
    let coinService: any CoinService
    let logger: Logger
    let event: Gateway.MessageReactionAdd
    private var cache: ReactionCache { .shared }
    
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
                client: discordClient,
                logger: logger
              ), user.id != receiverId
        else { return }
        let sender = "<@\(user.id)>"
        let receiver = "<@\(receiverId)>"
        
        let coinRequest = CoinRequest(
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
            logger.error("Error when posting coins", metadata: ["error": "\(error)"])
            await respond(
                with: "Oops. Something went wrong! Please try again later",
                senderName: nil
            )
            return
        }
        
        let senderName = member.nick ?? user.username
        if let (pennyResponseMessageId, lastUsers) = await cache.messageToEditIfAvailable(
            in: event.channel_id,
            receiverMessageId: event.message_id
        ) {
            let names = lastUsers.joined(separator: ", ") + " & \(senderName)"
            let count = lastUsers.count + 1
            await editResponse(
                messageId: pennyResponseMessageId,
                with: "\(names) gave \(count) \(Constants.vaporCoinEmoji) to \(response.receiver), who now has \(response.coins) \(Constants.vaporCoinEmoji)!",
                senderName: senderName
            )
        } else {
            await respond(
                with: "\(senderName) gave a \(Constants.vaporCoinEmoji) to \(response.receiver), who now has \(response.coins) \(Constants.vaporCoinEmoji)!",
                senderName: senderName
            )
        }
    }
    
    /// `senderName` only should be included if its not a error-response.
    private func respond(with response: String, senderName: String?) async {
        do {
            let apiResponse = try await discordClient.createMessage(
                channelId: event.channel_id,
                payload: .init(
                    embeds: [.init(
                        description: response,
                        color: .vaporPurple
                    )],
                    message_reference: .init(
                        message_id: event.message_id,
                        channel_id: event.channel_id,
                        guild_id: event.guild_id,
                        fail_if_not_exists: false
                    )
                )
            )
            if !(200..<300).contains(apiResponse.httpResponse.status.code) {
                logger.report("Received non-200 status from Discord API", response: apiResponse)
            } else {
                if let senderName {
                    let decoded = try apiResponse.decode()
                    await cache.didRespond(
                        in: event.channel_id,
                        to: event.message_id,
                        with: decoded.id,
                        senderName: senderName
                    )
                }
            }
        } catch {
            logger.error("Discord Client error", metadata: ["error": "\(error)"])
        }
    }
    
    /// `senderName` only should be included if its not a error-response.
    private func editResponse(
        messageId: String,
        with response: String,
        senderName: String?
    ) async {
        do {
            let apiResponse = try await discordClient.editMessage(
                channelId: event.channel_id,
                messageId: messageId,
                payload: .init(
                    embeds: [.init(
                        description: response,
                        color: .vaporPurple
                    )]
                )
            )
            if !(200..<300).contains(apiResponse.httpResponse.status.code) {
                logger.report("Received non-200 status from Discord API", response: apiResponse)
            } else {
                if let senderName {
                    let decoded = try apiResponse.decode()
                    await cache.didRespond(
                        in: event.channel_id,
                        to: event.message_id,
                        with: decoded.id,
                        senderName: senderName
                    )
                }
            }
        } catch {
            logger.error("Discord Client error", metadata: ["error": "\(error)"])
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
    
    private init() { }
    
    static var shared = ReactionCache()
    
    /// Returns author of the message.
    fileprivate func getAuthorId(
        channelId: String,
        messageId: String,
        client: any DiscordClient,
        logger: Logger
    ) async -> String? {
        if let authorId = cachedAuthorIds[messageId] {
            return authorId
        } else {
            do {
                let message = try await client.getChannelMessage(
                    channelId: channelId,
                    messageId: messageId
                ).decode()
                if let authorId = message.author?.id {
                    cachedAuthorIds[messageId] = authorId
                    return authorId
                } else {
                    logger.error("ReactionCache could not find a message's author id", metadata: [
                        "message": "\(message)"
                    ])
                    return nil
                }
            } catch {
                logger.error("ReactionCache could not find a message's author id", metadata: [
                    "error": "\(error)"
                ])
                return nil
            }
        }
    }
    
    /// This is to prevent spams. In case someone removes their reaction and reacts again,
    /// we should not give coins to message's author anymore.
    fileprivate func canGiveCoin(
        fromSender senderId: String,
        toAuthorOfMessage messageId: String
    ) -> Bool {
        givenCoins.insert([senderId, messageId]).inserted
    }
    
    fileprivate func didRespond(
        in channelId: String,
        to receiverMessageId: String,
        with responseMessageId: String,
        senderName: String
    ) {
        let names = (channelWithLastThanksMessage[channelId]?.2 ?? []) + [senderName]
        channelWithLastThanksMessage[channelId] = (receiverMessageId, responseMessageId, names)
    }
    
    fileprivate func messageToEditIfAvailable(
        in channelId: String,
        receiverMessageId: String
    ) -> (pennyResponseMessageId: String, lastUsers: [String])? {
        if let existing = channelWithLastThanksMessage[channelId] {
            if existing.0 == receiverMessageId {
                return (existing.1, existing.2)
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
    static func tests_reset() {
        shared = .init()
    }
#endif
}
