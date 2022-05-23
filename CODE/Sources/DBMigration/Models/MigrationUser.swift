//
//  File.swift
//  
//
//  Created by Benny De Bock on 19/04/2022.
//

import Foundation
import PennyModels

struct MigrationUser: Codable {
    public let id: UUID
    public let discordID: String?
    public let githubID: String?
    public let slackID: String?
    public var numberOfCoins: Int
    public var coinEntries: [CoinEntry]
    public let createdAt: Date
    
    public init(id: UUID, discordID: String?, githubID: String?, slackID: String?, numberOfCoins: Int, coinEntries: [CoinEntry], createdAt: Date)
    {
        self.id = id
        self.discordID = discordID
        self.githubID = githubID
        self.slackID = slackID
        self.numberOfCoins = numberOfCoins
        self.coinEntries = coinEntries
        self.createdAt = createdAt
    }
    
    public mutating func addCoinEntry(_ entry: CoinEntry) {
        coinEntries.append(entry)
        numberOfCoins = numberOfCoins + entry.amount
    }
}
