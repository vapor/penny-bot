import Atomics
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

    static let idGenerator = ManagedAtomic(UInt(0))

    let tableName = "ghHooks-message-lookup-table"

    init(awsClient: AWSClient, logger: Logger) {
        let euWest = Region(awsRegionName: "eu-west-1")
        self.db = DynamoDB(client: awsClient, region: euWest)
        var logger = logger
        logger[metadataKey: "repo"] = "\(Self.self)"
        self.logger = logger
    }

    private func makeTicketID(repoID: Int, number: Int) -> String {
        "\(repoID)_\(number)"
    }

    func getMessageID(repoID: Int, number: Int) async throws -> String {
        let item = try await self.getItem(repoID: repoID, number: number)
        if item.isUnavailable {
            throw Errors.unavailable
        }
        return item.messageID
    }

    private func getItem(repoID: Int, number: Int) async throws -> Item {
        let id = makeTicketID(repoID: repoID, number: number)
        let item = try await self.get(id: id)
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

    private func get(id: String) async throws -> Item {
        let requestID = Self.idGenerator.loadThenWrappingIncrement(ordering: .relaxed)
        logger.trace(
            "Will get an item",
            metadata: [
                "id": .string(id),
                "repo-request-id": .stringConvertible(requestID),
            ]
        )
        let query = DynamoDB.QueryInput(
            expressionAttributeValues: [":v1": .s(id)],
            keyConditionExpression: "id = :v1",
            limit: 1,
            tableName: self.tableName
        )
        let result = try await db.query(
            query,
            type: Item.self,
            logger: self.logger
        )
        logger.debug(
            "Got some items",
            metadata: [
                "items": "\(result.items ?? [])",
                "repo-request-id": .stringConvertible(requestID),
            ]
        )
        guard let item = result.items?.first else {
            throw Errors.notFound
        }
        return item
    }

    private func save(item: Item) async throws {
        let requestID = Self.idGenerator.loadThenWrappingIncrement(ordering: .relaxed)
        logger.debug(
            "Will save an item",
            metadata: [
                "item": "\(item)",
                "repo-request-id": .stringConvertible(requestID),
            ]
        )
        let input = DynamoDB.UpdateItemCodableInput(
            key: ["id"],
            tableName: self.tableName,
            updateItem: item
        )

        _ = try await db.updateItem(
            input,
            logger: self.logger
        )

        logger.trace(
            "Item did save",
            metadata: [
                "repo-request-id": .stringConvertible(requestID)
            ]
        )
    }
}
