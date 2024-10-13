import DiscordBM
import Logging
import Models
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct ReactionHandler {

    enum Configuration {
        static let coinSignEmojis: Set<String> = [
            Constants.ServerEmojis.love.name,
            Constants.ServerEmojis.vapor.name,
            Constants.ServerEmojis.coin.name,
            Constants.ServerEmojis.doge.name,
            "🪙", "🚀",
            "❤️", "💙", "💜", "🤍", "🤎", "🖤", "💛", "💚", "🧡",
            "🩷", "🩶", "🩵", "💗", "💕", "😍", "😻", "🎉", "💯",
        ]
        + Constants.emojiSkins.map { "🙌\($0)" }
        + Constants.emojiSkins.map { "🙏\($0)" }
        + Constants.emojiSkins.flatMap { s in Constants.emojiGenders.map { g in "🙇\(s)\(g)" } }
    }

    let event: Gateway.MessageReactionAdd
    let context: HandlerContext
    var logger = Logger(label: "ReactionHandler")
    var cache: ReactionCache {
        context.reactionCache
    }

    init(event: Gateway.MessageReactionAdd, context: HandlerContext) {
        self.event = event
        self.context = context
        self.logger[metadataKey: "event"] = "\(event)"
    }
    
    func handle() async {
        guard let member = event.member,
              let user = member.user,
              user.bot != true,
              let emojiName = event.emoji.name,
              Configuration.coinSignEmojis.contains(emojiName),
              await cache.canGiveCoin(
                fromSender: user.id,
                toAuthorOfMessage: event.message_id,
                emoji: event.emoji,
                reactionKind: event.type
              ),
              let receiverId = event.message_author_id,
              user.id != receiverId
        else { return }

        /// Super reactions give more coins, otherwise only 1 coin
        let amount = event.type == .super ? 3 : 1

        let coinRequest = UserRequest.CoinEntryRequest(
            amount: amount,
            fromDiscordID: user.id,
            toDiscordID: receiverId,
            source: .discord,
            reason: .userProvided
        )
        
        var response: CoinResponse?
        do {
            response = try await context.usersService.postCoin(with: coinRequest)
        } catch {
            logger.report("Error when posting coins", error: error)
            response = nil
        }
        
        guard await cache.messageCanBeRespondedTo(
            channelId: event.channel_id,
            messageId: event.message_id,
            context: context
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
                var newNames = info.senderUsers
                newNames.append(senderName)
                let names = newNames.joined(separator: ", ", lastSeparator: " & ")
                let count = info.totalCoinCount + amount
                await editResponse(
                    messageId: info.pennyResponseMessageId,
                    with: "\(names) gave \(count) \(Constants.ServerEmojis.coin.emoji) to \(DiscordUtils.mention(id: response.receiver)), who now has \(response.newCoinCount) \(Constants.ServerEmojis.coin.emoji)!",
                    forcedInThanksChannel: false,
                    amount: amount,
                    senderName: senderName
                )
            case let .forcedInThanksChannel(info):
                var newNames = info.senderUsers
                newNames.append(senderName)
                let names = newNames.joined(separator: ", ", lastSeparator: " & ")
                let link = "https://discord.com/channels/\(Constants.vaporGuildId.rawValue)/\(info.originalChannelId.rawValue)/\(event.message_id.rawValue)"
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
        let apiResponse = await context.discordService.sendThanksResponse(
            channelId: event.channel_id,
            replyingToMessageId: event.message_id,
            isFailureMessage: isFailureMessage,
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
        let apiResponse = await context.discordService.editMessage(
            messageId: messageId,
            channelId: forcedInThanksChannel ? Constants.Channels.thanks.id : event.channel_id,
            payload: .init(
                embeds: [.init(
                    description: response,
                    color: .purple
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

private func + (lhs: Set<String>, rhs: [String]) -> Set<String> {
    lhs.union(rhs)
}
