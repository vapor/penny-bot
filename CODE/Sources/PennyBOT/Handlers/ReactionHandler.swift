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
    
    func handle() async {
        guard let member = event.member,
              let user = member.user,
              user.bot != true,
              let emoji = event.emoji.name,
              coinSignEmojis.contains(emoji),
              await ReactionCache.shared.canGiveCoin(
                fromSender: user.id,
                toAuthorOfMessage: event.message_id
              ), let receiverId = await ReactionCache.shared.getAuthorId(
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
            logger.error("Error when posting coins: \(error)")
            await respond(with: "Oops. Something went wrong! Please try again later")
            return
        }
        await respond(with: "`\(member.nick ?? user.username)` gave a coin to \(response.receiver), who now has \(response.coins) \(Constants.vaporCoinEmoji)!")
    }
    
    private func respond(with response: String) async {
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
            ).httpResponse
            if !(200..<300).contains(apiResponse.status.code) {
                logger.error("Received non-200 status from Discord API: \(apiResponse)")
            }
        } catch {
            logger.error("Discord Client error: \(error)")
        }
    }
}

/// Cache for reactions-related stuff.
///
/// Optimally we would use some service like Redis to handle time-to-live
/// and disk-persistence for us, but this actor is more than enough at our scale.
private actor ReactionCache {
    /// `[MessageID: AuthorID]`
    var cachedAuthorIds: [String: String] = [:]
    /// `Set<[SenderID, MessageID]>`
    var givenCoins: Set<[String]> = []
    
    static let shared = ReactionCache()
    
    /// Returns author of the message.
    func getAuthorId(
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
                    logger.error("ReactionCache could not find a message's author id. message: \(message)")
                    return nil
                }
            } catch {
                logger.error("ReactionCache could not find a message's author id. Error: \(error)")
                return nil
            }
        }
    }
    
    /// This is to prevent spams. In case someone removes their reaction and reacts again,
    /// we should not give coins to message's author anymore.
    func canGiveCoin(
        fromSender senderId: String,
        toAuthorOfMessage messageId: String
    ) -> Bool {
        givenCoins.insert([senderId, messageId]).inserted
    }
}
