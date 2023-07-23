import DiscordBM
import Logging
import Models
import Foundation

private let coinSignEmojis = [
    Constants.ServerEmojis.love.name,
    Constants.ServerEmojis.vapor.name,
    Constants.ServerEmojis.coin.name,
    "🪙",
    "❤️", "💙", "💜", "🤍", "🤎", "🖤", "💛", "💚", "🧡",
    "💗", "💖", "💞", "❣️", "💓", "💘", "💝", "💕", "❤️‍🔥", "💟",
    "😍", "😻",
    "🚀",
    "🙌", "🙌🏻", "🙌🏼", "🙌🏽", "🙌🏾", "🙌🏿",
    "🙏", "🙏🏻", "🙏🏼", "🙏🏽", "🙏🏾", "🙏🏿",
    "👌", "👌🏻", "👌🏼", "👌🏽", "👌🏾", "👌🏿",
]

struct ReactionHandler {
    let event: Gateway.MessageReactionAdd
    var logger = Logger(label: "ReactionHandler")
    var coinService: any CoinService {
        ServiceFactory.makeCoinService()
    }
    private var cache: ReactionCache { .shared }
    
    init(event: Gateway.MessageReactionAdd) {
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
              ),
              let receiverId = event.message_author_id,
              user.id != receiverId
        else { return }

        /// Super reactions give more coins, otherwise only 1 coin
        let amount = event.type == .super ? 3 : 1

        let coinRequest = UserRequest.DiscordCoinEntry(
            amount: amount,
            fromDiscordID: user.id,
            toDiscordID: receiverId,
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
                isFailureMessage: true
            )
            return
        }
        
        let senderName = member.nick ?? user.global_name ?? user.username
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
                    with: "\(names) gave \(count) \(Constants.ServerEmojis.coin.emoji) to \(DiscordUtils.mention(id: response.receiver)), who now has \(response.newCoinCount) \(Constants.ServerEmojis.coin.emoji)!",
                    forcedInThanksChannel: false,
                    amount: amount,
                    senderName: senderName
                )
            case let .forcedInThanksChannel(info):
                let link = "https://discord.com/channels/\(Constants.vaporGuildId.rawValue)/\(info.originalChannelId.rawValue)/\(event.message_id.rawValue)"
                let names = info.senderUsers.joined(separator: ", ") + " & \(senderName)"
                let count = info.totalCoinCount + amount
                await editResponse(
                    messageId: info.pennyResponseMessageId,
                    with: "\(names) gave \(count) \(Constants.ServerEmojis.coin.emoji) to \(DiscordUtils.mention(id: response.receiver)), who now has \(response.newCoinCount) \(Constants.ServerEmojis.coin.emoji)! (\(link))",
                    forcedInThanksChannel: true,
                    amount: amount,
                    senderName: senderName
                )
            }
        } else {
            let coinCountDescription = amount == 1 ?
            "a \(Constants.ServerEmojis.coin.emoji)" :
            "\(amount) \(Constants.ServerEmojis.coin.emoji)"
            await respond(
                with: "\(senderName) gave \(coinCountDescription) to \(DiscordUtils.mention(id: response.receiver)), who now has \(response.newCoinCount) \(Constants.ServerEmojis.coin.emoji)!",
                amount: amount,
                senderName: senderName,
                isFailureMessage: false
            )
        }
    }
    
    /// `senderName` only should be included if its not a error-response.
    private func respond(
        with response: String,
        amount: Int,
        senderName: String?,
        isFailureMessage: Bool
    ) async {
        let apiResponse = await DiscordService.shared.sendThanksResponse(
            channelId: event.channel_id,
            replyingToMessageId: event.message_id,
            isFailureMessage: isFailureMessage,
            userToExplicitlyMention: nil,
            response: response
        )
        do {
            if let senderName,
               let decoded = try apiResponse?.decode() {
                /// If it's a thanks message that was sent to `#thanks` instead of the original
                /// channel, then we need to inform the cache.
                let sentToThanksChannelInstead = decoded.channel_id == Constants.Channels.thanks.id &&
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
            channelId: forcedInThanksChannel ? Constants.Channels.thanks.id : event.channel_id,
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

