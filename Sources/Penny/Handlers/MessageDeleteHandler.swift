import DiscordBM
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
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
            channelId: Constants.Channels.modLogs.id,
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
        var fields: [Embed.Field] = [
            .init(
                name: "Author",
                value: DiscordUtils.mention(id: author.id),
                inline: true
            ),
            .init(
                name: "Username",
                value: DiscordUtils.escapingSpecialCharacters(author.username),
                inline: true
            ),
        ]
        if messages.count > 1 {
            fields.append(
                .init(
                    name: "Edits",
                    value: "\(messages.count - 1)",
                    inline: true
                )
            )
        }
        let attachmentName = "message_history_\(lastMessage.id.rawValue)"
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
                fields: fields
            )],
            files: [.init(
                data: ByteBuffer(data: jsonData),
                filename: attachmentName
            )],
            attachments: [.init(
                index: 0,
                filename: attachmentName
            )]
        )
    }
}

/// Unused for now:

private extension Gateway.MessageCreate {
    /// Hash of the deterministic content of the message.
    /// For example doesn't include IDs which will change even if messages are the same.
    var partialHash: Int {
        let author = self.author?.id.rawValue.hashValue ?? 0
        let content = self.content.hashValue
        let attachments = self.attachments.map(\.filename.hashValue).reduce(into: 0, ^=)
        let embeds = self.embeds.map(\.partialHash).reduce(into: 0, ^=)
        let type = self.type.rawValue.hashValue
        let member = self.member?.user?.id.rawValue.hashValue ?? 0

        return author ^
        content ^
        attachments ^
        embeds ^
        type ^
        member
    }
}

private extension [Gateway.MessageCreate] {
    /// Hash of the deterministic content of the messages.
    /// For example doesn't include IDs which will change even if messages are the same.
    var partialHash: Int {
        self.map(\.partialHash).reduce(into: 0, ^=)
    }
}

private extension Embed {
    var partialHash: Int {
        let title = self.title?.hashValue ?? 0
        let type = self.type?.rawValue.hashValue ?? 0
        let description = self.description?.hashValue ?? 0
        let url = self.url?.hashValue ?? 0
        let footer = self.footer?.text.hashValue ?? 0
        let image = self.image?.height.hashValue ?? 0
        let thumbnail = self.thumbnail?.height.hashValue ?? 0
        let video = self.video?.height.hashValue ?? 0
        let provider = self.provider?.name.hashValue ?? 0
        let author = self.author?.name.hashValue ?? 0
        let fields = self.fields?.map {
            $0.name.hashValue ^ $0.value.hashValue
        }.reduce(into: 0, ^=) ?? 0

        return title ^
        type ^
        description ^
        url ^
        footer ^
        image ^
        thumbnail ^
        video ^
        provider ^
        author ^
        fields
    }
}
