import Foundation
import Models
import SotoDynamoDB

struct DynamoUserRepository {

    enum Configuration {
        static let githubIDNilEquivalent = " "
    }

    let db: DynamoDB
    let logger: Logger

    let tableName = "penny-user-table"
    let discordIndex = "D-ID-GSI"
    let githubIndex = "GH-ID-GSI"

    init(db: DynamoDB, logger: Logger) {
        self.db = db
        self.logger = logger
    }

    func createUser(_ user: DynamoDBUser) async throws {
        let input = DynamoDB.PutItemCodableInput(item: user, tableName: self.tableName)

        _ = try await db.putItem(input, logger: self.logger)
    }

    func updateUser(_ user: DynamoDBUser) async throws {
        var user = user

        if (user.githubID ?? "").isEmpty {
            /// Can't set this to `nil` or empty string when it's already populated.
            /// So `" "` (a single whitespace) is an equivalent for `nil`.
            user.githubID = Configuration.githubIDNilEquivalent
        }

        let input = DynamoDB.UpdateItemCodableInput(
            key: ["id"],
            tableName: self.tableName,
            updateItem: user
        )
        _ = try await db.updateItem(input, logger: self.logger)
    }

    func getUser(discordID: UserSnowflake) async throws -> DynamoDBUser? {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s(discordID.rawValue)],
            indexName: discordIndex,
            keyConditionExpression: "\(DynamoDBUser.CodingKeys.discordID) = :v1",
            limit: 1,
            tableName: self.tableName
        )

        return try await queryUser(with: query)
    }

    func getUser(githubID: String) async throws -> DynamoDBUser? {
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s(githubID)],
            indexName: githubIndex,
            keyConditionExpression: "\(DynamoDBUser.CodingKeys.githubID) = :v1",
            limit: 1,
            tableName: self.tableName
        )

        return try await queryUser(with: query)
    }

    /// Returns nil if user does not exist.
    private func queryUser(with query: DynamoDB.QueryInput) async throws -> DynamoDBUser? {
        var user = try await db.query(
            query,
            type: DynamoDBUser.self,
            logger: self.logger
        ).items?.first

        if user?.githubID == Configuration.githubIDNilEquivalent {
            /// Can't set this to `nil` or empty string when it's already populated.
            /// So `" "` (a single whitespace) is an equivalent for `nil`.
            user?.githubID = nil
        }

        return user
    }
}
