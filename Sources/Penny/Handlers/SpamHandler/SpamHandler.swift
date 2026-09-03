import DiscordBM
import Logging
import NIOCore
import NIOFoundationEssentialsCompat
import OrderedCollections
import Shared

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct SpamHandler {

    static let timeoutDuration: Duration = .seconds(60 * 60 * 6)
    static let reason = "Suspicious activity: writing to multiple channels at once"

    let event: Gateway.MessageCreate
    let context: HandlerContext
    var discordService: DiscordService {
        context.discordService
    }
    var logger = Logger(label: "SpamHandler")

    init(event: Gateway.MessageCreate, context: HandlerContext) {
        self.event = event
        self.context = context
        self.logger[metadataKey: "event"] = "\(event)"
    }

    func handle() async {
        guard let author = event.author,
            author.bot != true,
            author.id != Constants.botId,
            event.guild_id == Constants.vaporGuildId
        else { return }

        for role in event.member?.roles ?? [] {
            if Constants.Roles.elevatedPublicCommandsAccessSet.contains(role) {
                return
            }
        }

        switch await context.spamCache.recordAndCheck(event, of: author.id) {
        case .notSpam:
            return
        case .alreadyFlagged:
            await discordService.deleteMessage(
                messageId: event.id,
                channelId: event.channel_id,
                reason: Self.reason
            )
        case .spam(let entries):
            await discordService.timeoutMember(
                userId: author.id,
                for: Self.timeoutDuration,
                reason: Self.reason
            )
            let messagesWindow = SpamCache<ContinuousClock>.window + .seconds(5)
            let cachedMessages = await discordService.getCachedMessages(of: author.id, in: messagesWindow)
            await discordService.sendMessage(
                channelId: Constants.Channels.modLogs.id,
                payload: self.makeMessagePayload(
                    spamEntries: entries,
                    messages: cachedMessages,
                    lastMessage: event,
                    author: author
                )
            )
            await self.removeMessages(of: entries, and: cachedMessages)
        }
    }

    /// The `entries` are what was detected, while the `messages` are only what the Discord cache
    /// happened to have. The cache is populated concurrently with this handler being called, so it
    /// can be missing the very messages that triggered the detection.
    private func removeMessages(
        of entries: [SpamCache<ContinuousClock>.Entry],
        and messages: [Gateway.MessageCreate]
    ) async {
        var removed = Set<MessageSnowflake>(minimumCapacity: entries.count + messages.count)
        for entry in entries where removed.insert(entry.messageId).inserted {
            await discordService.deleteMessage(
                messageId: entry.messageId,
                channelId: entry.channelId,
                reason: Self.reason
            )
        }
        for message in messages where removed.insert(message.id).inserted {
            await discordService.deleteMessage(
                messageId: message.id,
                channelId: message.channel_id,
                reason: Self.reason
            )
        }
    }

    func makeMessagePayload(
        spamEntries entries: [SpamCache<ContinuousClock>.Entry],
        messages: [Gateway.MessageCreate],
        lastMessage: Gateway.MessageCreate,
        author: DiscordUser
    ) -> Payloads.CreateMessage {
        let member = lastMessage.member
        let avatarURL = member?.uiAvatarURL ?? author.uiAvatarURL
        let channels = OrderedSet(entries.map(\.channelId))
        let attachmentName = "spam_messages_\(lastMessage.id.rawValue)"
        let encoder = JSONEncoder()
        let jsonData = (try? encoder.encode(messages)) ?? Data()

        return .init(
            embeds: [
                .init(
                    title: "Spam messages detected",
                    description:
                        DiscordUtils
                        .escapingSpecialCharacters(lastMessage.content)
                        .unicodesPrefix(2_048)
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
                            name: "Username",
                            value: author.username,
                            inline: true
                        ),
                        .init(
                            name: "Count",
                            value: "\(entries.count)",
                            inline: true
                        ),
                        .init(
                            name: "Timeout Duration",
                            value: "\(Self.timeoutDuration)",
                            inline: true
                        ),
                        .init(
                            name: "Channels",
                            value: channels.map(DiscordUtils.mention(id:)).joined(separator: ", ").unicodesPrefix(1024)
                        ),
                    ]
                )
            ],
            files: [
                .init(
                    data: ByteBuffer(data: jsonData),
                    filename: attachmentName
                )
            ],
            attachments: [
                .init(
                    index: 0,
                    filename: attachmentName
                )
            ]
        )
    }
}
