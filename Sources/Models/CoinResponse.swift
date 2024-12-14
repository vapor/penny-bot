package struct CoinResponse: Sendable, Codable {
    package let sender: UserSnowflake
    package let receiver: UserSnowflake
    package let newCoinCount: Int

    package init(sender: UserSnowflake, receiver: UserSnowflake, newCoinCount: Int) {
        self.sender = sender
        self.receiver = receiver
        self.newCoinCount = newCoinCount
    }
}
