//
//  File.swift
//  
//
//  Created by Benny De Bock on 08/03/2022.
//

import Foundation

// Coun suffix doesn't work
let validSuffixes = [
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

public struct CoinReq : Codable {
    let value: Int
    let receiver: String
}

public struct CoinRes : Codable {
    let message: String
}

extension String {
    var hasCoinSuffix: Bool {
        for suffix in validSuffixes where hasSuffix(suffix) {
            return true
        }
        return false
    }
    
    var containsUser: Bool {
        let parts = self.split(separator: " ")
        
        for part in parts {
            if part.hasPrefix("<@!") {
                return true
            }
        }
        
        return false
    }
    
    var getUser: String {
        let parts = self.split(separator: " ")
        
        for part in parts {
            if part.hasPrefix("<@!") {
                return String(part)
            }
        }
        
        return "blank"
    }
}
