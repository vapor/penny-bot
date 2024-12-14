import DiscordModels

extension Embed: @retroactive Equatable {
    public static func == (lhs: Embed, rhs: Embed) -> Bool {
        lhs.title == rhs.title && lhs.type == rhs.type && lhs.description == rhs.description && lhs.url == rhs.url
            && lhs.timestamp?.date == rhs.timestamp?.date && lhs.color == rhs.color && lhs.footer == rhs.footer
            && lhs.image == rhs.image && lhs.thumbnail == rhs.thumbnail && lhs.video == rhs.video
            && lhs.provider == rhs.provider && lhs.author == rhs.author && lhs.fields == rhs.fields
    }
}

extension Embed.Media: @retroactive Equatable {
    public static func == (lhs: Embed.Media, rhs: Embed.Media) -> Bool {
        lhs.url.asString == rhs.url.asString && lhs.proxy_url ?== rhs.proxy_url && lhs.height ?== rhs.height
            && lhs.width ?== rhs.width
    }
}

extension Embed.Footer: @retroactive Equatable {
    public static func == (lhs: Embed.Footer, rhs: Embed.Footer) -> Bool {
        lhs.icon_url?.asString == rhs.icon_url?.asString && lhs.text == rhs.text && lhs.proxy_icon_url
            ?== rhs.proxy_icon_url
    }
}

extension Embed.Provider: @retroactive Equatable {
    public static func == (lhs: Embed.Provider, rhs: Embed.Provider) -> Bool {
        lhs.url == rhs.url && lhs.name == rhs.name
    }
}

extension Embed.Author: @retroactive Equatable {
    public static func == (lhs: Embed.Author, rhs: Embed.Author) -> Bool {
        lhs.url == rhs.url && lhs.icon_url?.asString == rhs.icon_url?.asString && lhs.name == rhs.name
            && lhs.proxy_icon_url ?== rhs.proxy_icon_url
    }
}

extension Embed.Field: @retroactive Equatable {
    public static func == (lhs: Embed.Field, rhs: Embed.Field) -> Bool {
        lhs.name == rhs.name && lhs.value == rhs.value && lhs.inline ?== rhs.inline
    }
}

infix operator ?== : ComparisonPrecedence

/// Returns `true` if any of the values is `nil`, or if both values are the same. Otherwise `false`.
/// This is used for the fields that even if we send `nil` for, Discord might populate them itself.
private func ?== <E: Equatable>(lhs: E?, rhs: E?) -> Bool {
    switch (lhs, rhs) {
    case (.none, _):
        return true
    case (_, .none):
        return true
    case let (.some(lhs), .some(rhs)):
        return lhs == rhs
    }
}
