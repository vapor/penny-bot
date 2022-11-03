
public struct CoinRequest: Codable {
    public let amount: Int
    public let from: String
    public let receiver: String
    public let source: CoinEntrySource
    public let reason: CoinEntryReason
    
    public init(amount: Int, from: String, receiver: String, source: CoinEntrySource, reason: CoinEntryReason) {
        self.amount = amount
        self.from = from
        self.receiver = receiver
        self.source = source
        self.reason = reason
    }
}

public enum CoinEntrySource: String, Codable {
    case discord
    case github
    case penny
}

public enum CoinEntryReason: String, Codable {
    case userProvided
    case prSubmittedAndClosed
    case startedSponsoring
    case transferred
    case linkedProfile
}
