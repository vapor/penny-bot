//
//  File.swift
//  
//
//  Created by Benny De Bock on 08/03/2022.
//

import Foundation

// Coun suffix doesn't work
private let validSuffixes = [
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
    /// Users to not be able to get a coin. Such as the author of the message.
    let excludedUsers: [String]
    /// Maximum users allowed to get a new coin in one message.
    let maxUsers = 10
    
    /// Finds users that need to get a coin, if anyone at all.
    func findUsers() -> [String] {
        var finalUsers = [String]()
        
        for line in text.split(whereSeparator: \.isNewline) {
            if finalUsers.count == maxUsers { break }
            
            let components = line
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
                .enumerated()
            let allMentions = components.filter(\.element.isUserMention)
            
            var usersWithNewCoins = [String]()
            
            for mention in allMentions {
                for (offset, element) in components where offset > mention.offset {
                    // If there are some user mentions in a row and there is a thanks-suffix after those, they should all get a coin.
                    if element.isUserMention { continue }
                    
                    if components.dropFirst(offset).isPrefixedWithCoinSuffix,
                       !usersWithNewCoins.contains(mention.element) {
                        usersWithNewCoins.append(mention.element)
                    }
                    
                    break
                }
            }
            
            // The logic above doesn't take care of message starting with @s and ending in a coin
            // suffix. If there were no users found so far, we will try to check for this case.
            if usersWithNewCoins.isEmpty,
               components.isSuffixedWithCoinSuffix {
                for component in components {
                    if component.element.isUserMention {
                        usersWithNewCoins.append(component.element)
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
        
        return finalUsers
    }
}

private extension String {
    var isUserMention: Bool {
        hasSuffix(">") && hasPrefix("<@") && {
            /// Make sure the third element is a number and is not something like `!`.
            /// Because if the string starts with `<@!` it means it's a role id not a user id.
            /// We can add role support later,
            /// something to give all people with the role a coin perhaps.
            let index = self.index(self.startIndex, offsetBy: 2)
            return self[index].isNumber
        }()
    }
}

private let departedSuffixes = validSuffixes.map {
    $0.split(whereSeparator: \.isWhitespace).map(String.init)
}

private extension Sequence where Element == (offset: Int, element: String) {
    var isPrefixedWithCoinSuffix: Bool {
        let elements = self.map(\.element)
        return departedSuffixes.contains {
            elements.starts(with: $0)
        }
    }
    
    var isSuffixedWithCoinSuffix: Bool {
        let reversedElements = self.map(\.element).reversed()
        return departedSuffixes.contains {
            reversedElements.starts(with: $0.reversed())
        }
    }
}
