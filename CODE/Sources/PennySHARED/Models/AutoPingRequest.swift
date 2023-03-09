
public struct AutoPingRequest: Codable {
    public let discordID: String
    public let texts: [String]
    
    public init(
        discordID: String,
        texts: [String]
    ) {
        self.discordID = discordID
        self.texts = texts
    }
}
