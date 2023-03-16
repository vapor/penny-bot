
public struct AutoPingRequest: Codable {
    /// The plain id. like `1021219291291`. NOT `<@1021219291291>`.
    public let discordID: String
    public let texts: [String]
    
    /// - Parameters:
    ///   - discordID: The plain id. like `1021219291291`. NOT `<@1021219291291>`.
    public init(
        discordID: String,
        texts: [String]
    ) {
        self.discordID = discordID
        self.texts = texts
    }
}
