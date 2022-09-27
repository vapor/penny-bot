import DiscordBM
import Logging
import PennyModels

private let coinSignEmojis = [
    "🪙",
    "coin-1"
]

struct ReactionHandler {
    let discordClient: DiscordClient
    let coinService: CoinService
    let logger: Logger
    let event: Gateway.MessageReactionAdd
    
    func handle() async {
        guard let user = event.member?.user,
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
        
        let oops = "Oops. Something went wrong! Please try again later"
        let response: String
        do {
            response = try await self.coinService.postCoin(with: coinRequest)
        } catch {
            return await respondToMessage(with: oops, channelId: event.channel_id)
        }
        if response.starts(with: "ERROR-") {
            logger.error("Received an incoming error: \(response)")
            await respondToMessage(with: oops, channelId: event.channel_id)
        } else {
            await ReactionCache.shared.didGiveCoin(
                fromSender: user.id,
                toAuthorOfMessage: event.message_id
            )
            await respondToMessage(with: response, channelId: event.channel_id)
        }
    }
    
    private func respondToMessage(with response: String, channelId: String) async {
        do {
            let apiResponse = try await discordClient.createMessage(
                channelId: channelId,
                payload: .init(content: response)
            ).raw
            if !(200..<300).contains(apiResponse.status.code) {
                logger.error("Received non-200 status from Discord API: \(apiResponse)")
            }
        } catch {
            logger.error("Discord Client error: \(error)")
        }
    }
}

/// Cache for message authors.
///
/// Optimally you would use some service like Redis to handle time-to-live
/// and disk-persistence for you, but this actor will suffice for us.
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
        client: DiscordClient,
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
        givenCoins.contains([senderId, messageId])
    }
    
    func didGiveCoin(
        fromSender senderId: String,
        toAuthorOfMessage messageId: String
    ) {
        givenCoins.insert([senderId, messageId])
    }
}