
public struct AutoPingRequest: Codable {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
}
