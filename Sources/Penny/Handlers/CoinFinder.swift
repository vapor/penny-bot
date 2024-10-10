import Foundation
import DiscordBM

struct CoinFinder {

    enum Configuration {
        /// All coin signs must be lowercased.
        /// Add a test when you add a coin sign.
        static let coinSigns = [
            Constants.ServerEmojis.coin.emoji,
            Constants.ServerEmojis.love.emoji,
            "🚀", "🎉", "💯", "🪙",
            "thx", "thanks", "thank you",
            "thanks a lot", "thanks a bunch", "thanks so much",
            "thank you a lot", "thank you a bunch", "thank you so much",
            "thanks for the help", "thanks for your help",
            "+= 1", "+ 1"
        ]
        + Constants.emojiSkins.map { "🙌\($0)" }
        + Constants.emojiSkins.map { "🙏\($0)" }

        /// Two or more of these characters, like `++` or `++++++++++++`.
        static let twoOrMore_coinSigns: [Character] = ["+"]

        /// Maximum users allowed to get a new coin in one message.
        static let maxUsers = 10
    }

    /// The content of the message.
    let text: String
    /// User that was replied to, if any.
    let repliedUser: UserSnowflake?
    /// Users that are mentioned and able to get coins. These are validated by Discord.
    /// Using this is to prevent giving coins to normal texts that look like user-ids.
    let mentionedUsers: [UserSnowflake]
    /// Users to not be able to get a coin. Such as the author of the message.
    let excludedUsers: [UserSnowflake]
    
    /// Finds users that need to get a coin, if anyone at all.
    func findUsers() -> [UserSnowflake] {
        // If there are no mentioned users or replied users,
        // then there is no way that anyone will get any coins.
        if mentionedUsers.isEmpty && (repliedUser == nil) {
            return []
        }
        
        // Lowercased for case-insensitive coin-sign checking.
        var text = text
            .lowercased()
        /// Punctuations can be problematic if someone sticks it to the end of a coin sign, like
        /// "@Penny thanks, ..." or  "@Penny thanks!"
            .removingOccurrences(of: undesiredCharacterSet)
        
        for mentionedUser in mentionedUsers {
            // Replacing `mentionedUser` with `" " + mentionedUser + " "` because
            // if there is a user mention in the text and there are no spaces after
            // or behind it, the logic below won't be able to catch the mention since
            // it relies on spaces to find meaningful components of each line.
            // These extra spaces are filtered later.
            let mention = DiscordUtils.mention(id: mentionedUser)
            text.replace(mention, with: " \(mention) ")
        }
        
        let lines = text.split(whereSeparator: \.isNewline)
        
        var finalUsers = [UserSnowflake]()

        // Start trying to find the users that should get a coin.
        for line in lines {
            if finalUsers.count == Configuration.maxUsers { break }

            let components = line
                .split(whereSeparator: \.isWhitespace)
                .filter({ !$0.isIgnorable })
            let enumeratedComponents = components.enumerated()
            let allMentions = enumeratedComponents.filter({ isUserMention($0.element) })

            var usersWithNewCoins = [UserSnowflake]()
            // Not using `Set` to keep order. Will look nicer to users.
            func append(user: Substring) {
                /// Turns `<@ID>`s to `ID`.
                let user = user.dropFirst(2).dropLast()
                if !usersWithNewCoins.contains(where: { $0.rawValue.elementsEqual(user) }),
                   !excludedUsers.contains(where: { $0.rawValue.elementsEqual(user) }),
                   !finalUsers.contains(where: { $0.rawValue.elementsEqual(user) }) {
                    usersWithNewCoins.append(UserSnowflake(String(user)))
                }
            }
            
            for mention in allMentions {
                
                // If the coin sign is in front of the @s
                if let after = enumeratedComponents.first(where: { offset, component in
                    offset > mention.offset && !isUserMention(component)
                }), components.dropFirst(after.offset).isPrefixedWithCoinSign {
                    append(user: mention.element)
                    continue
                }
                
                // If the coin sign is behind the @s
                if let before = enumeratedComponents.reversed().first(where: { offset, component in
                    offset < mention.offset && !isUserMention(component)
                }), components.dropLast(components.count - before.offset - 1).isSuffixedWithCoinSign {
                    append(user: mention.element)
                    continue
                }
            }
            
            // If there were no users found so far, we try to check if
            // the message starts with @s and ends in a coin sign.
            if usersWithNewCoins.isEmpty,
               components.isSuffixedWithCoinSign {
                for component in components {
                    if isUserMention(component) {
                        append(user: component)
                    } else {
                        break
                    }
                }
            }

            // If there were no users found so far, we try to check if
            // the message starts with a coin sign and ends in @s.
            if usersWithNewCoins.isEmpty,
               components.isPrefixedWithCoinSign {
                for component in components.reversed() {
                    if isUserMention(component) {
                        append(user: component)
                    } else {
                        break
                    }
                }
            }

            let minLhs = Configuration.maxUsers - finalUsers.count
            let remainingCapacity = min(minLhs, usersWithNewCoins.count)
            let dropCount = usersWithNewCoins.count - remainingCapacity
            finalUsers.append(contentsOf: usersWithNewCoins.dropLast(dropCount))
        }
        
        // Here we check to see if the message was in reply to another message and contains
        // a coin sign in a proper place.
        // It would mean that someone has replied to another one and thanked them.
        if let repliedUser = repliedUser,
           !excludedUsers.contains(repliedUser),
           !finalUsers.contains(repliedUser) {
            
            // At the beginning of the first line.
            if let firstLine = lines.first {
                let components = firstLine
                    .split(whereSeparator: \.isWhitespace)
                    .filter({ !$0.isEmpty })
                if components.isPrefixedWithCoinSign {
                    finalUsers.append(repliedUser)
                }
            }
            
            // At the end of the last line, only if there are no other users that get any coins.
            if finalUsers.isEmpty, let lastLine = lines.last {
                let components = lastLine
                    .split(whereSeparator: \.isWhitespace)
                    .filter({ !$0.isEmpty })
                if components.isSuffixedWithCoinSign {
                    finalUsers.append(repliedUser)
                }
            }
        }
        
        return finalUsers
    }
    
    private func isUserMention(_ string: Substring) -> Bool {
        let stringNoSurroundings = string.dropFirst(2).dropLast()
        /// `.hasPrefix()` is for a better performance.
        /// Should remove a lot of no-match strings, much faster than the containment check.
        return string.hasPrefix("<@") &&
        string.hasSuffix(">") &&
        mentionedUsers.contains(where: { $0.rawValue.elementsEqual(stringNoSurroundings) })
    }
}

private let undesiredCharacterSet = CharacterSet.punctuationCharacters.subtracting(["@", ":"])
private let splitSigns = CoinFinder.Configuration.coinSigns.map {
    $0.split(whereSeparator: \.isWhitespace)
}

/// It's safe but apparently the underlying type doesn't declare a proper conditional Sendable conformance.
private let reversedSplitSigns = splitSigns.map { $0.reversed() }

private extension Sequence<Substring> {
    var isPrefixedWithCoinSign: Bool {
        return splitSigns.contains {
            self.starts(with: $0)
        } || self.isPrefixedWithOtherCoinSigns
    }
    
    var isSuffixedWithCoinSign: Bool {
        let reversedElements = self.reversed()
        return reversedSplitSigns.contains {
            reversedElements.starts(with: $0)
        } || reversedElements.isPrefixedWithOtherCoinSigns
    }
    
    /// Coins signs that accept two or more of the same character.
    private var isPrefixedWithOtherCoinSigns: Bool {
        self.first(where: { _ in true }).map { element in
            CoinFinder.Configuration.twoOrMore_coinSigns.contains { sign in
                element.underestimatedCount > 1 &&
                element.allSatisfy({ sign == $0 })
            }
        } == true
    }
}

private extension Substring {
    private static let ignorable = Set(["", "and", "&"])

    /// These strings are considered neutral, and in the logic above we can ignore them.
    ///
    /// NOTE: The logic in `CoinHandler`, intentionally adds spaces after and before each
    /// user-mention. That means we _need_ to remove empty strings to neutralize those
    /// intentional spaces.
    var isIgnorable: Bool {
        Self.ignorable.contains(self.lowercased())
    }
}
