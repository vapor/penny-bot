import DiscordBM
import Foundation
import Algorithms
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

    func handle(messageIds: [MessageSnowflake]) async throws {
        var allMessages: [[Gateway.MessageCreate]] = []
        allMessages.reserveCapacity(messageIds.count)

        for messageId in messageIds {
            guard let messages = await discordService.getDeletedMessageWithEditions(
                id: messageId
            ) else {
                logger.warning("Could not find any saved messages for a deleted message", metadata: [
                    "messageId": .string(messageId.rawValue)
                ])
                continue
            }
            allMessages.append(messages)
        }

        let groupedAllMessages = allMessages.grouped(by: \.partialHash)

        for (_, groupedMessages) in groupedAllMessages {
            guard groupedMessages.count > 0 else { continue }

            let messages = groupedMessages[0]
            guard let lastMessage = messages.last else {
                logger.error("Cannot find any message in array of messages", metadata: [
                    "messages": .string("\(messages)")
                ])
                return
            }
            guard let author = lastMessage.author else {
                logger.error("Cannot find author of a deleted message", metadata: [
                    "messageId": .string(lastMessage.id.rawValue),
                    "channelId": .string(lastMessage.channel_id.rawValue),
                    "messages": .string("\(messages)")
                ])
                return
            }
            if try await discordService.userIsModerator(userId: author.id) {
                logger.debug("User is a moderator so won't report message deletion", metadata: [
                    "messageId": .string(lastMessage.id.rawValue),
                    "channelId": .string(lastMessage.channel_id.rawValue),
                    "messages": .string("\(messages)")
                ])
                return
            }

            if groupedMessages.count == 1 {
                await discordService.sendMessage(
                    channelId: Constants.Channels.moderators.id,
                    payload: .init(
                        messages: messages,
                        author: author
                    )
                )
            } else {
                await discordService.sendMessage(
                    channelId: Constants.Channels.moderators.id,
                    payload: .init(
                        messagesSample: messages,
                        messageIds: groupedMessages.compactMap(\.first).map(\.id),
                        in: groupedMessages.compactMap(\.first).map(\.channel_id),
                        author: author
                    )
                )
            }
        }
    }
}

private extension Payloads.CreateMessage {
    /// Used for deletion of a single message.
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
        let quotedContent = DiscordUtils
            .escapingSpecialCharacters(lastMessage.content)
            .quotedMarkdown()
        self.init(
            embeds: [.init(
                title: "Deleted Message",
                description: """
                In: \(DiscordUtils.mention(id: lastMessage.channel_id))
                \(quotedContent)
                """,
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

    /// Used for bulk-deletion of messages with partially the same content (e.g. spams).
    init(
        messagesSample: [Gateway.MessageCreate],
        messageIds: [MessageSnowflake],
        in channels: [ChannelSnowflake],
        author: DiscordUser
    ) {
        /// `messagesSample` is non-empty.
        let lastMessage = messagesSample.last!
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
                value: author.username,
                inline: true
            ),
            .init(
                name: "Author ID",
                value: author.id.rawValue,
                inline: true
            ),
        ]
        if messagesSample.count > 1 {
            fields.append(
                .init(
                    name: "Edits",
                    value: "\(messagesSample.count - 1)",
                    inline: true
                )
            )
        }
        let attachmentName = "message_sample_history_\(lastMessage.id.rawValue)"
        let jsonData = (try? JSONEncoder().encode(messagesSample)) ?? Data()
        let quotedContent = DiscordUtils
            .escapingSpecialCharacters(lastMessage.content)
            .quotedMarkdown()

        self.init(
            embeds: [.init(
                title: "Bulk-Deleted Messages",
                description: """
                In: \(channels.map(DiscordUtils.mention(id:)).joined(separator: ", "))
                \(quotedContent)
                """,
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
