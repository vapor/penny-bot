
public struct AutoPingRequest: Codable {
    /// The plain id. like `1021219291291`. NOT `<@1021219291291>`.
    public let discordID: String
    public let expressions: [S3AutoPingItems.Expression]
    
    /// - Parameters:
    ///   - discordID: The plain id. like `1021219291291`. NOT `<@1021219291291>`.
    public init(
        discordID: String,
        expressions: [S3AutoPingItems.Expression]
    ) {
        self.discordID = discordID
        self.expressions = expressions
    }
}
