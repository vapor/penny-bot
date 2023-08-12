
public struct AutoPingsRequest: Codable {
    public let discordID: UserSnowflake
    public let expressions: [S3AutoPingItems.Expression]
    
    public init(
        discordID: UserSnowflake,
        expressions: [S3AutoPingItems.Expression]
    ) {
        self.discordID = discordID
        self.expressions = expressions
    }
}
