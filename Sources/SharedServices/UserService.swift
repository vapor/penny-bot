import SotoDynamoDB
import Foundation
import Models

public struct UserService {
    private let userRepo: DynamoUserRepository
    private let coinEntryRepo: DynamoCoinEntryRepository
    let logger: Logger

    #warning("remove")
    let dynamoDB: DynamoDB

    public init(awsClient: AWSClient, logger: Logger) {
        let euWest = Region(awsRegionName: "eu-west-1")
        let dynamoDB = DynamoDB(client: awsClient, region: euWest)
        #warning("remove")
        self.dynamoDB = dynamoDB
        self.userRepo = DynamoUserRepository(
            db: dynamoDB,
            logger: logger
        )
        self.coinEntryRepo = DynamoCoinEntryRepository(
            db: dynamoDB,
            logger: logger
        )
        self.logger = logger
    }

    /// `freshUser` must be a fresh user you just got from the db.
    public func addCoinEntry(
        _ coinEntry: CoinEntry,
        freshUser user: DynamoDBUser
    ) async throws -> DynamoDBUser {
        try await coinEntryRepo.createCoinEntry(coinEntry)
        
        var user = user
        user.coinCount += coinEntry.amount
        try await userRepo.updateUser(user)

        return user
    }

    /// Returns nil if user does not exist.
    func getUser(discordID: UserSnowflake) async throws -> DynamoDBUser? {
        try await userRepo.getUser(discordID: discordID)
    }

    public func getOrCreateUser(discordID: UserSnowflake) async throws -> DynamoDBUser {
        if let existing = try await self.getUser(discordID: discordID) {
            return existing
        } else {
            let newUser = DynamoDBUser.createNew(forDiscordID: discordID)
            try await userRepo.createUser(newUser)
            return newUser
        }
    }
    
    /// Returns nil if user does not exist.
    public func getUser(githubID: String) async throws -> DynamoDBUser? {
        try await userRepo.getUser(githubID: githubID)
    }

    public func linkGithubID(discordID: UserSnowflake, githubID: String) async throws {
        var user = try await self.getOrCreateUser(discordID: discordID)
        user.githubID = githubID

        try await userRepo.updateUser(user)
    }

    #warning("remove")
    public func performMigration() async {
        logger.warning("Starting Migration. Getting all users")
        let query = DynamoDB.QueryInput(
            limit: nil,
            tableName: "penny-bot-table"
        )

        let items: [OldDynamoDBUser]?
        do {
            items = try await dynamoDB.query(
                query,
                type: OldDynamoDBUser.self,
                logger: self.logger,
                on: dynamoDB.eventLoopGroup.any()
            ).items
        } catch {
            logger.warning("query failed will retry in 10s, \(error)")
            try? await Task.sleep(for: .seconds(10))
            await self.performMigration()
            return
        }

        guard let items = items, !items.isEmpty else {
            logger.warning("Migration Stopped. Query is empty")
            return
        }
        logger.warning("Got \(items.count) items")

        for (idx, item) in items.enumerated() {
            if idx % 20 == 0 {
                logger.warning("At index \(idx) of \(items.count)")
            }

            let id = item.pk
            /// `USER-C07AAD42-1DB5-441F-BBC9-0B50DD7372D3`
            guard id.hasPrefix("USER-") else {
                logger.warning("bad user id: \(item)")
                continue
            }
            guard let uuid = UUID(uuidString: String(id.dropFirst(5))) else {
                logger.warning("Couldn't convert to uuid: \(item)")
                continue
            }

            guard var discordID = item.data1 else {
                logger.warning("No discord id for item with pk \(item.pk)")
                continue
            }
            /// `DISCORD-<@135838305873952778>`
            if discordID.hasPrefix("DISCORD-<@"), discordID.hasSuffix(">") {
                discordID = String(discordID.dropFirst(10).dropLast())
            }
            if UInt(discordID) == nil || UserSnowflake(discordID).parse() == nil {
                logger.warning("Bad Discord ID Int: \(discordID), item: \(item)")
            }

            var githubID: String? = item.data2
            if let id = githubID, Int(id) == nil {
                logger.warning("Bad Github ID: \(githubID ?? "<null>"), item: \(item)")
                githubID = nil
            }

            var user = DynamoDBUser(
                id: uuid,
                discordID: UserSnowflake(discordID),
                githubID: githubID,
                coinCount: item.amountOfCoins ?? 0,
                createdAt: item.createdAt
            )

            let entries = (item.coinEntries ?? []).compactMap {
                entry -> CoinEntry? in
                guard let from = entry.from else {
                    logger.warning("entry.from is nil. entry: \(entry), item: \(item)")
                    return nil
                }
                return CoinEntry(
                    id: entry.id,
                    fromUserID: from,
                    toUserID: user.id,
                    createdAt: entry.createdAt,
                    amount: entry.amount,
                    source: entry.source,
                    reason: entry.reason
                )
            }

            do {
                try await self.userRepo.createUser(user)
            } catch {
                logger.warning("could not create user: \(error), item: \(item), user: \(user)")
            }

            for entry in entries {
                do {
                    user = try await self.addCoinEntry(entry, freshUser: user)
                } catch {
                    logger.warning("could not add entry: \(entry), item: \(item), user: \(user)")
                }
            }
        }

        logger.warning("will perform another round")
        await self.performMigration()
    }
}

#warning("remove")
private struct OldDynamoDBUser: Sendable, Codable {

    public struct CoinEntry: Sendable, Codable {
        public let id: UUID
        public let createdAt: Date
        public let amount: Int
        public let from: UUID?
        public let source: CoinEntrySource
        public let reason: CoinEntryReason
    }

    public let pk: String
    public let sk: String
    public let data1: String?
    public let data2: String?
    public let amountOfCoins: Int?
    public let coinEntries: [CoinEntry]?
    public let createdAt: Date
}
