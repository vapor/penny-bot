
public struct AutoPingRequest: Codable {
    public let texts: [String]
    
    public init(texts: [String]) {
        self.texts = texts
    }
}
