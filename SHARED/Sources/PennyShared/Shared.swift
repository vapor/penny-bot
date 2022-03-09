public struct CoinRequest: Codable {
    public let receiver: String
    public let value: Int
    
    public init(receiver: String, value: Int) {
        self.receiver = receiver
        self.value = value
    }
}

public struct CoinResponse: Codable {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}
