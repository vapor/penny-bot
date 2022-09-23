//
//  File.swift
//  
//
//  Created by Benny De Bock on 08/03/2022.
//

import Foundation

// Coun suffix doesn't work
private let validSigns = [
    "++",
    "🪙",
    ":coin:",
    "+= 1",
    "+ 1",
    "advance(by: 1)",
    "successor()",
    "👍",
    ":+1:",
    ":thumbsup:",
    "🙌",
    ":raised_hands:",
    "🚀",
    ":rocket:",
    "thanks",
    "thanks!",
    "thank you",
    "thank you!",
    "thx",
    "thx!"
]

struct CoinReq : Codable {
    let value: Int
    let receiver: String
}

struct CoinRes : Codable {
    let message: String
}

struct CoinHandler {
    /// The content of the message.
    let text: String
    /// User that was replied to, if any.
    let repliedUser: String?
    /// Users to not be able to get a coin. Such as the author of the message.
    let excludedUsers: [String]
    /// Maximum users allowed to get a new coin in one message.
    let maxUsers = 10
    
    /// Finds users that need to get a coin, if anyone at all.
    func findUsers() -> [String] {
        var finalUsers = [String]()
        
        let lines = text.split(whereSeparator: \.isNewline)
        for line in lines {
            if finalUsers.count == maxUsers { break }
            
            let components = line
                .split(whereSeparator: \.isWhitespace)
                .filter({ !$0.isIgnorable })
            let enumeratedComponents = components.enumerated()
            let allMentions = enumeratedComponents.filter(\.element.isUserMention)
            
            var usersWithNewCoins = [String]()
            // Not using `Set` to keep order. Will look nicer to users.
            func appendUser(_ user: Substring) {
                if !usersWithNewCoins.contains(where: { $0.elementsEqual(user) }) {
                    usersWithNewCoins.append(String(user))
                }
            }
            
        outerLoop:
            for mention in allMentions {
                
                // If the coin sign is in front of the @s
                for (offset, element) in enumeratedComponents
                where offset > mention.offset {
                    // If there are some user mentions in a row and there is a coin-sign after those, they should all get a coin.
                    if element.isUserMention { continue }
                    
                    if components.dropFirst(offset).isPrefixedWithCoinSign {
                        appendUser(mention.element)
                        continue outerLoop
                    }
                    
                    break
                }
                
                // If the coin sign is behind of the @s
                for (offset, element) in enumeratedComponents.reversed()
                where offset < mention.offset {
                    // If there are some user mentions in a row and there is a coin-suffix before those, they should all get a coin.
                    if element.isUserMention { continue }
                    
                    let dropCount = components.count - offset - 1
                    if components.dropLast(dropCount).isSuffixedWithCoinSign {
                        appendUser(mention.element)
                    }
                    
                    break
                }
            }
            
            // The logic above doesn't take care of message starting with @s and ending in a coin
            // sign. If there were no users found so far, we try to check for this case.
            if usersWithNewCoins.isEmpty,
               components.isSuffixedWithCoinSign {
                for component in components {
                    if component.isUserMention {
                        appendUser(component)
                    } else {
                        break
                    }
                }
            }
            
            let validUsers = usersWithNewCoins.filter {
                !excludedUsers.contains($0) && !finalUsers.contains($0)
            }
            let count = finalUsers.count + validUsers.count
            if count > maxUsers {
                let remainingCapacity = min(count - maxUsers, maxUsers)
                finalUsers.append(
                    contentsOf: validUsers.dropLast(validUsers.count - remainingCapacity)
                )
            } else {
                finalUsers.append(contentsOf: validUsers)
            }
        }
        
        // If we don't have any users at all, we check to see if the message was in reply
        // to another message and contains a coin sign in a proper place.
        // It would mean that someone has replied to another one and thanked them.
        if let repliedUser = repliedUser,
           !excludedUsers.contains(repliedUser),
           finalUsers.isEmpty {
            
            // At the beginning of the first line.
            if let firstLine = lines.first {
                let components = firstLine
                    .split(whereSeparator: \.isWhitespace)
                    .filter({ !$0.isEmpty })
                if components.isPrefixedWithCoinSign {
                    finalUsers.append(repliedUser)
                }
            }
            
            // At the end of the last line.
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
}

private extension Substring {
    var isUserMention: Bool {
        hasSuffix(">") && hasPrefix("<@") && {
            /// Make sure the third element is a number and is not something like `!`.
            /// Because if the string starts with `<@!` it means it's a role id not a user id.
            /// We can add role support later,
            /// something to give all people with the role a coin, perhaps.
            let index = self.index(self.startIndex, offsetBy: 2)
            return self[index].isNumber
        }()
    }
}

private let splitSuffixes = validSigns.map {
    $0.split(whereSeparator: \.isWhitespace)
}

private let reversedSplitSuffixes = splitSuffixes.map {
    $0.reversed()
}

private extension Sequence where Element == Substring {
    var isPrefixedWithCoinSign: Bool {
        return splitSuffixes.contains {
            self.starts(with: $0)
        }
    }
    
    var isSuffixedWithCoinSign: Bool {
        let reversedElements = self.reversed()
        return reversedSplitSuffixes.contains {
            reversedElements.starts(with: $0)
        }
    }
}

private extension Substring {
    /// "and", ",", and empty strings are considered neutral,
    /// and in the logic above we can ignore them.
    var isIgnorable: Bool {
        self.isEmpty || {
            let lowercased = self.lowercased()
            return lowercased == "and" || lowercased == ","
        }()
    }
}
