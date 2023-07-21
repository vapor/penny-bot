import SotoDynamoDB

struct DynamoMessageRepo: MessageLookupRepo {

    enum Errors: Error, CustomStringConvertible {
        case notFound

        var description: String {
            switch self {
            case .notFound:
                return "notFound"
            }
        }
    }

    struct Item: Codable {
        let id: String
        let messageID: String
    }

    let db: DynamoDB
    let logger: Logger

    let tableName = "ghHooks-message-lookup-table"

    init(awsClient: AWSClient, logger: Logger) {
        let euWest = Region(awsRegionName: "eu-west-1")
        self.db = DynamoDB(client: awsClient, region: euWest)
        self.logger = logger
    }

    private func makeOperationID(repoID: Int, number: Int) -> String {
        "\(repoID)_\(number)"
    }

    func getMessageID(repoID: Int, number: Int) async throws -> String {
        let id = makeOperationID(repoID: repoID, number: number)
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s(id)],
            keyConditionExpression: "id = :v1",
            limit: 1,
            tableName: self.tableName
        )
        let results = try await db.query(
            query,
            type: Item.self,
            logger: self.logger,
            on: self.db.eventLoopGroup.any()
        )
        guard let item = results.items?.first else {
            throw Errors.notFound
        }
        return item.messageID
    }

    func saveMessageID(messageID: String, repoID: Int, number: Int) async throws {
        let id = makeOperationID(repoID: repoID, number: number)
        let item = Item(id: id, messageID: messageID)
        let input = DynamoDB.UpdateItemCodableInput(
            key: ["id"],
            tableName: self.tableName,
            updateItem: item
        )

        _ = try await db.updateItem(
            input,
            logger: self.logger,
            on: self.db.eventLoopGroup.any()
        )
    }
}
