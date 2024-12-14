import Models
import SotoDynamoDB

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

package struct InternalUsersService {
    private let userRepo: DynamoUserRepository
    private let coinEntryRepo: DynamoCoinEntryRepository
    let logger: Logger

    package init(awsClient: AWSClient, logger: Logger) {
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
    package func addCoinEntry(
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

    package func getOrCreateUser(discordID: UserSnowflake) async throws -> DynamoDBUser {
        if let existing = try await self.getUser(discordID: discordID) {
            return existing
        } else {
            let newUser = DynamoDBUser.createNew(forDiscordID: discordID)
            try await userRepo.createUser(newUser)
            return newUser
        }
    }

    /// Returns nil if user does not exist.
    package func getUser(githubID: String) async throws -> DynamoDBUser? {
        try await userRepo.getUser(githubID: githubID)
    }

    package func linkGithubID(discordID: UserSnowflake, githubID: String) async throws {
        var user = try await self.getOrCreateUser(discordID: discordID)
        user.githubID = githubID

        try await userRepo.updateUser(user)
    }

    package func unlinkGithubID(discordID: UserSnowflake) async throws {
        var user = try await self.getOrCreateUser(discordID: discordID)
        user.githubID = nil

        try await userRepo.updateUser(user)
    }
}
