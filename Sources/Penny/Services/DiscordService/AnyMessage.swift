import DiscordBM

/// Either a `Gateway.MessageCreate` or a `DiscordChannel.Message`.
enum AnyMessage {
    /// The message object which is received through the Gateway.
    case messageCreate(Gateway.MessageCreate)
    /// The message object usually retrieved from API endpoints.
    case message(DiscordChannel.Message)

    init(_ message: Gateway.MessageCreate) {
        self = .messageCreate(message)
    }

    init(_ message: DiscordChannel.Message) {
        self = .message(message)
    }

    var id: MessageSnowflake {
        switch self {
        case .messageCreate(let message):
            return message.id
        case .message(let message):
            return message.id
        }
    }

    var channel_id: ChannelSnowflake {
        switch self {
        case .messageCreate(let message):
            return message.channel_id
        case .message(let message):
            return message.channel_id
        }
    }

    var author: DiscordUser? {
        switch self {
        case .messageCreate(let message):
            return message.author
        case .message(let message):
            return message.author
        }
    }

    var content: String {
        switch self {
        case .messageCreate(let message):
            return message.content
        case .message(let message):
            return message.content
        }
    }

    var timestamp: DiscordTimestamp {
        switch self {
        case .messageCreate(let message):
            return message.timestamp
        case .message(let message):
            return message.timestamp
        }
    }

    var edited_timestamp: DiscordTimestamp? {
        switch self {
        case .messageCreate(let message):
            return message.edited_timestamp
        case .message(let message):
            return message.edited_timestamp
        }
    }

    var tts: Bool {
        switch self {
        case .messageCreate(let message):
            return message.tts
        case .message(let message):
            return message.tts
        }
    }

    var mention_everyone: Bool {
        switch self {
        case .messageCreate(let message):
            return message.mention_everyone
        case .message(let message):
            return message.mention_everyone
        }
    }

    var mention_roles: [RoleSnowflake] {
        switch self {
        case .messageCreate(let message):
            return message.mention_roles
        case .message(let message):
            return message.mention_roles
        }
    }

    var mention_channels: [DiscordChannel.Message.ChannelMention]? {
        switch self {
        case .messageCreate(let message):
            return message.mention_channels
        case .message(let message):
            return message.mention_channels
        }
    }

    var mentions: [MentionUser] {
        switch self {
        case .messageCreate(let message):
            return message.mentions
        case .message(let message):
            return message.mentions
        }
    }

    var attachments: [DiscordChannel.Message.Attachment] {
        switch self {
        case .messageCreate(let message):
            return message.attachments
        case .message(let message):
            return message.attachments
        }
    }

    var embeds: [Embed] {
        switch self {
        case .messageCreate(let message):
            return message.embeds
        case .message(let message):
            return message.embeds
        }
    }

    var reactions: [DiscordChannel.Message.Reaction]? {
        switch self {
        case .messageCreate(let message):
            return message.reactions
        case .message(let message):
            return message.reactions
        }
    }

    var nonce: StringOrInt? {
        switch self {
        case .messageCreate(let message):
            return message.nonce
        case .message(let message):
            return message.nonce
        }
    }

    var pinned: Bool {
        switch self {
        case .messageCreate(let message):
            return message.pinned
        case .message(let message):
            return message.pinned
        }
    }

    var webhook_id: WebhookSnowflake? {
        switch self {
        case .messageCreate(let message):
            return message.webhook_id
        case .message(let message):
            return message.webhook_id
        }
    }

    var type: DiscordChannel.Message.Kind {
        switch self {
        case .messageCreate(let message):
            return message.type
        case .message(let message):
            return message.type
        }
    }

    var activity: DiscordChannel.Message.Activity? {
        switch self {
        case .messageCreate(let message):
            return message.activity
        case .message(let message):
            return message.activity
        }
    }

    var application: PartialApplication? {
        switch self {
        case .messageCreate(let message):
            return message.application
        case .message(let message):
            return message.application
        }
    }

    var application_id: ApplicationSnowflake? {
        switch self {
        case .messageCreate(let message):
            return message.application_id
        case .message(let message):
            return message.application_id
        }
    }

    var message_reference: DiscordChannel.Message.MessageReference? {
        switch self {
        case .messageCreate(let message):
            return message.message_reference
        case .message(let message):
            return message.message_reference
        }
    }

    var flags: IntBitField<DiscordChannel.Message.Flag>? {
        switch self {
        case .messageCreate(let message):
            return message.flags
        case .message(let message):
            return message.flags
        }
    }

    var interaction: MessageInteraction? {
        switch self {
        case .messageCreate(let message):
            return message.interaction
        case .message(let message):
            return message.interaction
        }
    }

    var thread: DiscordChannel? {
        switch self {
        case .messageCreate(let message):
            return message.thread
        case .message(let message):
            return message.thread
        }
    }

    var components: [Interaction.ActionRow]? {
        switch self {
        case .messageCreate(let message):
            return message.components
        case .message(let message):
            return message.components
        }
    }

    var sticker_items: [StickerItem]? {
        switch self {
        case .messageCreate(let message):
            return message.sticker_items
        case .message(let message):
            return message.sticker_items
        }
    }

    var stickers: [Sticker]? {
        switch self {
        case .messageCreate(let message):
            return message.stickers
        case .message(let message):
            return message.stickers
        }
    }

    var position: Int? {
        switch self {
        case .messageCreate(let message):
            return message.position
        case .message(let message):
            return message.position
        }
    }

    var role_subscription_data: RoleSubscriptionData? {
        switch self {
        case .messageCreate(let message):
            return message.role_subscription_data
        case .message(let message):
            return message.role_subscription_data
        }
    }
}
