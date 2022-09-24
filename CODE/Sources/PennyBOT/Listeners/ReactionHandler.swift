//
//  File.swift
//
//
//  Created by Mahdi Bahrami on 25/10/22.
//

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
              let receiverId = await ReactionCache.shared.getAuthorId(
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

private actor ReactionCache {
    /// [[ChannelID, MessageID]: AuthorID]
    var cachedAuthorIds: [[String]: String] = [:]
    
    static let shared = ReactionCache()
    
    func getAuthorId(
        channelId: String,
        messageId: String,
        client: DiscordClient,
        logger: Logger
    ) async -> String? {
        let id = [channelId, messageId]
        if let authorId = cachedAuthorIds[id] {
            return authorId
        } else {
            do {
                let message = try await client.getChannelMessage(
                    channelId: channelId,
                    messageId: messageId
                ).decode()
                if let authorId = message.author?.id {
                    cachedAuthorIds[id] = authorId
                    return authorId
                } else {
                    return nil
                }
            } catch {
                logger.error("ReactionCache could not a message's author id. Error: \(error)")
                return nil
            }
        }
    }
}
