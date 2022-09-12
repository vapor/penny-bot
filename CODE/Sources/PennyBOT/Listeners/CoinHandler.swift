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
    let text: String
    let excludedUserIds: [String]
    
    /// Finds users that need to get a coin, if anyone at all.
    func findUsers() -> [String] {
        let components = text.components(separatedBy: " ").enumerated()
        let allMentions = components.filter(\.element.isUserMention)
        
        var usersWithNewCoins = [String]()
        
        for mention in allMentions {
            for (offset, element) in components where offset > mention.offset {
                // If there are some user mentions in a row and there is a thanks-suffix after those, they should all get a coin.
                if element.isUserMention { continue }
                
                if element.isCoinSuffix {
                    usersWithNewCoins.append(mention.element)
                } else {
                    break
                }
            }
        }
        
        // The logic above doesn't take care of message starting with @s and ending in a coin
        // suffix. If there were no users found so far, we will try to check for this case.
        if usersWithNewCoins.isEmpty,
           components.reversed().first?.element.isCoinSuffix == true {
            for mention in allMentions {
                if mention.element.isUserMention {
                    usersWithNewCoins.append(mention.element)
                } else {
                    break
                }
            }
        }
        
        // Support a maximum of 10 users in one message make abusing the bot harder.
        if usersWithNewCoins.count > 10 {
            return Array(usersWithNewCoins.dropLast(usersWithNewCoins.count - 10))
        } else {
            return usersWithNewCoins
        }
    }
}

private extension String {
    var isUserMention: Bool {
        hasPrefix("<@") && hasSuffix(">")
    }
    
    var isCoinSuffix: Bool {
        validSuffixes.contains(self)
    }
}
