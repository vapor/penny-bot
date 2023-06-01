import Foundation

public struct User: Codable {
    public let id: UUID
    public let userID: String
    public var numberOfCoins: Int
    public let createdAt: Date
    
    public init(id: UUID, userID: String, numberOfCoins: Int, createdAt: Date) {
        self.id = id
        self.userID = userID
        self.numberOfCoins = numberOfCoins
        self.createdAt = createdAt
    }
}
