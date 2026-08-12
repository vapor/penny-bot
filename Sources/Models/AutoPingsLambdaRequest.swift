package enum AutoPingsLambdaRequest: Sendable, Codable {
    case all
    case insert(UserExpressions)
    case remove(UserExpressions)

    package struct UserExpressions: Sendable, Codable {
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
}
