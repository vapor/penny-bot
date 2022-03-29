import Foundation

struct CoinEntry: Codable {
    let id: UUID
    let createdAt: Date
    let amount: Int
    let from: UUID?
    let source: CoinEntrySource
    let reason: CoinEntryReason
}
