#if canImport(Darwin)
import Foundation
#else
@preconcurrency import Foundation
#endif

public struct CoinEntry: Sendable, Codable {
    public let id: UUID
    public let fromUserID: UUID
    public let toUserID: UUID
    public let createdAt: Date
    public let amount: Int
    public let source: CoinEntrySource
    public let reason: CoinEntryReason
    
    public init(
        id: UUID = UUID(),
        fromUserID: UUID,
        toUserID: UUID,
        createdAt: Date = Date(),
        amount: Int,
        source: CoinEntrySource,
        reason: CoinEntryReason
    ) {
        self.id = id
        self.fromUserID = fromUserID
        self.toUserID = toUserID
        self.createdAt = createdAt
        self.amount = amount
        self.source = source
        self.reason = reason
    }
}
