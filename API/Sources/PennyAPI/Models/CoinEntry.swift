import Foundation

struct CoinEntry: Codable {
    let createdAt: Date
    let amount: Int
    let from: UUID?
    let source: CoinEntrySource
    let reason: CoinEntryReason
}

enum CoinEntrySource: String, Codable {
    case discord
    case github
    case penny
}

enum CoinEntryReason: String, Codable {
    case userProvided
    case prSubmittedAndClosed
    case startedSponsoring
}
