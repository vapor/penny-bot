package struct AutoPingsRequest: Codable {
    package let discordID: UserSnowflake
    package let expressions: [S3AutoPingItems.Expression]

    package init(
        discordID: UserSnowflake,
        expressions: [S3AutoPingItems.Expression]
    ) {
        self.discordID = discordID
        self.expressions = expressions
    }
}
