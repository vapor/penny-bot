import SotoDynamoDB
import Foundation
import Models

public struct UserService {
    
    public enum ServiceError: Error {
        case failedToUpdate
        case unimplemented(line: UInt = #line)
    }
    
    let logger: Logger
    let userRepo: DynamoUserRepository
    let tableName = "penny-bot-table"

    public init(_ awsClient: AWSClient, _ logger: Logger) {
        let euWest = Region(awsRegionName: "eu-west-1")
        let dynamoDB = DynamoDB(client: awsClient, region: euWest)
        self.logger = logger
        self.userRepo = DynamoUserRepository(
            db: dynamoDB,
            tableName: tableName,
            eventLoop: awsClient.eventLoopGroup.any(),
            logger: logger
        )
    }
    
    public func addCoins(
        with coinEntry: CoinEntry,
        fromDiscordID: String,
        to user: User
    ) async throws -> CoinResponse {
        var localUser: User?
        
        do {
            switch coinEntry.source {
            case .discord:
                localUser = try await userRepo.getUser(discord: user.discordID!)
            case .github:
                localUser = try await userRepo.getUser(github: user.githubID!)
            case .penny:
                throw ServiceError.unimplemented()
            }
        }
        catch let error {
            logger.error("Can't add coins", metadata: ["error": "\(error)"])
            throw ServiceError.failedToUpdate
        }
        
        if var localUser {
            localUser.addCoinEntry(coinEntry)
            let dbUser = DynamoDBUser(user: localUser)
            
            try await userRepo.updateUser(dbUser)
            return CoinResponse(
                sender: fromDiscordID,
                receiver: localUser.discordID!,
                coins: localUser.numberOfCoins
            )
        } else {
            let localUser = try await insertIntoDB(user: user, with: coinEntry)
            return CoinResponse(
                sender: fromDiscordID,
                receiver: localUser.discordID!,
                coins: localUser.numberOfCoins
            )
        }
    }
    
    public func getUserUUID(from user: User, with source: CoinEntrySource) async throws -> UUID {
        var localUser: User?
        
        do {
            switch source {
            case .discord:
                localUser = try await userRepo.getUser(discord: user.discordID!)
            case .github:
                localUser = try await userRepo.getUser(github: user.githubID!)
            case .penny:
                throw ServiceError.unimplemented()
            }
            
            return localUser?.id ?? UUID()
        }
        catch {
            return UUID()
        }
    }
    
    /// Returns nil if user does not exist.
    public func getUserWith(discordID id: String) async throws -> User? {
        try await userRepo.getUser(discord: id)
    }
    
    /// Returns nil if user does not exist.
    public func getUserWith(githubID id: String) async throws -> User? {
        try await userRepo.getUser(github: id)
    }
    
    private func insertIntoDB(user account: User, with coinEntry: CoinEntry) async throws -> User {
        var localUser = account
        
        localUser.addCoinEntry(coinEntry)
        
        let dbUser = DynamoDBUser(user: localUser)
        try await userRepo.insertUser(dbUser)
        
        return localUser
    }
}
