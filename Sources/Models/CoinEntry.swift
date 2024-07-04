#if canImport(Darwin)
import Foundation
#else
@preconcurrency import Foundation
#endif

package struct CoinEntry: Sendable, Codable {

    package enum Source: String, Sendable, Codable {
        case discord
        case github
        case penny
    }

    package enum Reason: String, Sendable, Codable {
        case userProvided
        case automationProvided
        case prSubmittedAndClosed
        /// `prMerge` is the new term for the old `prSubmittedAndClosed`.
        case prMerge
        case startedSponsoring
        case transferred
        case linkedProfile
    }

    package let id: UUID
    package let fromUserID: UUID
    package let toUserID: UUID
    package let createdAt: Date
    package let amount: Int
    package let source: Source
    package let reason: Reason
    
    package init(
        id: UUID = UUID(),
        fromUserID: UUID,
        toUserID: UUID,
        createdAt: Date = Date(),
        amount: Int,
        source: Source,
        reason: Reason
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
