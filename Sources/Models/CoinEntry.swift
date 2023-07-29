#if canImport(Darwin)
import Foundation
#else
@preconcurrency import Foundation
#endif

public struct CoinEntry: Sendable, Codable {

    public enum Source: String, Sendable, Codable {
        case discord
        case github
        case penny
    }

    public enum Reason: String, Sendable, Codable {
        case userProvided
        case automationProvided
        case prSubmittedAndClosed
        case startedSponsoring
        case transferred
        case linkedProfile
    }

    public let id: UUID
    public let fromUserID: UUID
    public let toUserID: UUID
    public let createdAt: Date
    public let amount: Int
    public let source: Source
    public let reason: Reason
    
    public init(
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
