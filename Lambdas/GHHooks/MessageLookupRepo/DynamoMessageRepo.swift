import SotoDynamoDB

struct DynamoMessageRepo: MessageLookupRepo {

    enum Errors: Error, CustomStringConvertible {
        case notFound
        case unavailable

        var description: String {
            switch self {
            case .notFound:
                return "notFound"
            case .unavailable:
                return "unavailable"
            }
        }
    }

    struct Item: Codable {
        let id: String
        let messageID: String
        fileprivate var _isUnavailable: Bool? = false

        var isUnavailable: Bool {
            self._isUnavailable ?? false
        }

        init(id: String, messageID: String) {
            self.id = id
            self.messageID = messageID
        }
    }

    let db: DynamoDB
    let logger: Logger

    let tableName = "ghHooks-message-lookup-table"

    init(awsClient: AWSClient, logger: Logger) {
        let euWest = Region(awsRegionName: "eu-west-1")
        self.db = DynamoDB(client: awsClient, region: euWest)
        self.logger = logger
    }

    private func makeTicketID(repoID: Int, number: Int) -> String {
        "\(repoID)_\(number)"
    }

    /// Returns nil if message is unavailable to edit.
    func getMessageID(repoID: Int, number: Int) async throws -> String {
        let item = try await self.getItem(repoID: repoID, number: number)
        if item.isUnavailable {
            throw Errors.unavailable
        }
        return item.messageID
    }

    private func getItem(repoID: Int, number: Int) async throws -> Item {
        let id = makeTicketID(repoID: repoID, number: number)
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
        return item
    }

    /// Marks the message as unavailable to edit, for example for when Penny sends a message
    /// for a ticket to Discord, but a moderator deletes that messages, then there is an update
    /// to the ticket, but the previous message is unavailable to edit anymore, so Penny should
    /// just ignore updates to messages of that ticket.
    func markAsUnavailable(repoID: Int, number: Int) async throws {
        var item = try await self.getItem(repoID: repoID, number: number)
        item._isUnavailable = true
        try await save(item: item)
    }

    func saveMessageID(messageID: String, repoID: Int, number: Int) async throws {
        let id = makeTicketID(repoID: repoID, number: number)
        let item = Item(id: id, messageID: messageID)
        try await save(item: item)
    }

    private func save(item: Item) async throws {
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
