import Foundation

public struct DynamoUser: Codable {
    public let id: UUID
    public let data1: String?
    public let data2: String?
    public var numberOfCoins: Int
    public var coinEntries: [CoinEntry]
    public let createdAt: Date
    
    public init(
        id: UUID,
        data1: String?,
        data2: String?,
        numberOfCoins: Int,
        coinEntries: [CoinEntry],
        createdAt: Date
    ) {
        self.id = id
        self.data1 = data1
        self.data2 = data2
        self.numberOfCoins = numberOfCoins
        self.coinEntries = coinEntries
        self.createdAt = createdAt
    }
    
    public mutating func addCoinEntry(_ entry: CoinEntry) {
        coinEntries.append(entry)
        numberOfCoins = numberOfCoins + entry.amount
    }
}
