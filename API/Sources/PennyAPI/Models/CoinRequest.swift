import Foundation

struct CoinRequest: Codable {
    let amount: Int
    let from: String
    let receiver: String
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
