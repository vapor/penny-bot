package import NewCodable

@JSONCodable
package enum AutoPingsLambdaRequest: Sendable {
    case all
    case insert(UserExpressions)
    case remove(UserExpressions)

    @JSONCodable
    package struct UserExpressions: Sendable {
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
