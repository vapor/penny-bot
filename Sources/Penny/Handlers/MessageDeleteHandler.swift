import DiscordBM
import Foundation
import Logging
import NIOCore
import NIOFoundationCompat
import Models

struct MessageDeleteHandler {
    let context: HandlerContext
    var discordService: DiscordService {
        context.services.discordService
    }
    let logger = Logger(label: "MessageDeleteHandler")

    init(context: HandlerContext) {
        self.context = context
    }

    func handle(
        messageId: MessageSnowflake,
        in channelId: ChannelSnowflake
    ) async throws {
        guard let messages = await discordService.getDeletedMessageWithEditions(
            id: messageId,
            channelId: channelId
        ) else {
            logger.warning("Could not find any saved messages for a deleted message", metadata: [
                "messageId": .string(messageId.rawValue),
                "channelId": .string(channelId.rawValue)
            ])
            return
        }
        guard let author = messages.last?.author else {
            logger.error("Cannot find author of a deleted message", metadata: [
                "messageId": .string(messageId.rawValue),
                "channelId": .string(channelId.rawValue),
                "messages": .string("\(messages)")
            ])
            return
        }
        if try await discordService.userIsModerator(userId: author.id) {
            logger.debug("User is a moderator so won't report message deletion", metadata: [
                "messageId": .string(messageId.rawValue),
                "channelId": .string(channelId.rawValue),
                "messages": .string("\(messages)")
            ])
            return
        }
        await discordService.sendMessage(
            channelId: Constants.Channels.moderators.id,
            payload: .init(
                messages: messages,
                author: author
            )
        )
    }
}

private extension Payloads.CreateMessage {
    init(
        messages: [Gateway.MessageCreate],
        author: DiscordUser
    ) {
        /// `messages` is non-empty.
        let lastMessage = messages.last!
        let member = lastMessage.member
        let avatarURL = member?.uiAvatarURL ?? author.uiAvatarURL
        let messageName = "message_history_\(lastMessage.id.rawValue)"
        let jsonData = (try? JSONEncoder().encode(messages)) ?? Data()
        self.init(
            embeds: [.init(
                title: "Deleted Message in \(DiscordUtils.mention(id: lastMessage.channel_id))",
                description: DiscordUtils
                    .escapingSpecialCharacters(lastMessage.content)
                    .quotedMarkdown(),
                timestamp: lastMessage.timestamp.date,
                color: .red,
                footer: .init(
                    text: "From \(member?.uiName ?? author.uiName)",
                    icon_url: avatarURL.map { .exact($0) }
                ),
                fields: [
                    .init(
                        name: "Author",
                        value: DiscordUtils.mention(id: author.id),
                        inline: true
                    ),
                    .init(
                        name: "Author Username",
                        value: author.username,
                        inline: true
                    ),
                    .init(
                        name: "Edits",
                        value: "\(messages.count - 1)",
                        inline: true
                    )
                ]
            )],
            files: [.init(
                data: ByteBuffer(data: jsonData),
                filename: messageName
            )],
            attachments: [.init(
                index: 0,
                filename: messageName
            )]
        )
    }
}
