
public struct DynamoDBAutoPingItem: Codable {
    public var discordUserID: String
    public var texts: [String]
    public var disabled: Bool
    
    public init(discordUserID: String, texts: [String], disabled: Bool = false) {
        self.discordUserID = discordUserID
        self.texts = texts
        self.disabled = disabled
    }
}
