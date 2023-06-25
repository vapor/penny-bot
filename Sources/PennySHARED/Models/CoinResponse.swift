
public struct CoinResponse: Sendable, Codable {
    public let sender: String
    public let receiver: String
    public let coins: Int
    
    public init(sender: String, receiver: String, coins: Int) {
        self.sender = sender
        self.receiver = receiver
        self.coins = coins
    }
}
