import Foundation
import Models
import SotoDynamoDB

public struct InternalUsersService {
    private let userRepo: DynamoUserRepository
    private let coinEntryRepo: DynamoCoinEntryRepository
    let logger: Logger

    public init(awsClient: AWSClient, logger: Logger) {
        let euWest = Region(awsRegionName: "eu-west-1")
        let dynamoDB = DynamoDB(client: awsClient, region: euWest)
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
        guard let existing = try await self.getUser(discordID: discordID) else {
            let newUser = DynamoDBUser.createNew(forDiscordID: discordID)
            try await userRepo.createUser(newUser)
            return newUser
        }
        return existing
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

    public func unlinkGithubID(discordID: UserSnowflake) async throws {
        var user = try await self.getOrCreateUser(discordID: discordID)
        user.githubID = nil

        try await userRepo.updateUser(user)
    }
}
