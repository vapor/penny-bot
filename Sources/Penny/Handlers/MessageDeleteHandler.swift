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
        guard let messageCreate = await discordService.getDeletedMessage(
            id: messageId,
            channelId: channelId
        ) else {
            logger.warning("Could not find a saved message for deleted message", metadata: [
                "messageId": .stringConvertible(messageId),
                "channelId": .stringConvertible(channelId)
            ])
            return
        }
        guard let author = messageCreate.author else {
            logger.error("Cannot find author of the message")
            return
        }
        if try await discordService.userIsModerator(userId: author.id) {
            logger.debug("User is a moderator so won't report message deletion", metadata: [
                "messageId": .stringConvertible(messageId),
                "channelId": .stringConvertible(channelId)
            ])
            return
        }
        await discordService.sendMessage(
            channelId: Constants.Channels.moderators.id,
            payload: .init(
                messageCreate: messageCreate,
                author: author
            )
        )
    }
}

private extension Payloads.CreateMessage {
    init(
        messageCreate: Gateway.MessageCreate,
        author: DiscordUser
    ) {
        let member = messageCreate.member
        let avatarURL = member?.uiAvatarURL ?? author.uiAvatarURL
        let messageName = "message_\(messageCreate.id.rawValue)"
        let jsonData = (try? JSONEncoder().encode(messageCreate)) ?? Data()
        self.init(
            embeds: [.init(
                title: "Deleted Message",
                description: DiscordUtils
                    .escapingSpecialCharacters(messageCreate.content)
                    .quotedMarkdown(),
                timestamp: messageCreate.timestamp.date,
                color: .red,
                footer: .init(
                    text: "From @\(member?.uiName ?? author.uiName)",
                    icon_url: avatarURL.map { .exact($0) }
                ),
                fields: [
                    .init(
                        name: "Author",
                        value: DiscordUtils.mention(id: author.id),
                        inline: true
                    ),
                    .init(
                        name: "Author ID",
                        value: author.id.rawValue,
                        inline: true
                    ),
                    .init(
                        name: "Author Username",
                        value: author.username,
                        inline: true
                    ),
                    .init(
                        name: "Channel",
                        value: DiscordUtils.mention(id: messageCreate.channel_id),
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
