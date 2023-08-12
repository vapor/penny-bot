public struct CoinResponse: Sendable, Codable {
    public let sender: UserSnowflake
    public let receiver: UserSnowflake
    public let newCoinCount: Int

    public init(sender: UserSnowflake, receiver: UserSnowflake, newCoinCount: Int) {
        self.sender = sender
        self.receiver = receiver
        self.newCoinCount = newCoinCount
    }
}
