import Foundation

public struct CoinEntry: Codable {
    
    public struct From: Codable {
        public let userID: UUID
        public let discordID: String
        
        public init(userID: UUID, discordID: String) {
            self.userID = userID
            self.discordID = discordID
        }
    }
    
    public let id: UUID
    public let createdAt: Date
    public let amount: Int
    public let from: From
    public let source: CoinEntrySource
    public let reason: CoinEntryReason
    
    public init(id: UUID, createdAt: Date, amount: Int, from: From, source: CoinEntrySource, reason: CoinEntryReason) {
        self.id = id
        self.createdAt = createdAt
        self.amount = amount
        self.from = from
        self.source = source
        self.reason = reason
    }
}
