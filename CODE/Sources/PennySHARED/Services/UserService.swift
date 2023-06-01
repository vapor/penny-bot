import SotoDynamoDB
import Foundation
import PennyRepositories
import PennyModels

public struct UserService {
    
    public enum ServiceError: Error {
        case failedToUpdate
        case unimplemented(line: UInt = #line)
    }
    
    let logger: Logger
    let userRepo: any UserRepository
    
    public init(_ awsClient: AWSClient, _ logger: Logger) {
        let euWest = Region(awsRegionName: "eu-west-1")
        let dynamoDB = DynamoDB(client: awsClient, region: euWest)
        self.logger = logger
        self.userRepo = RepositoryFactory.makeUserRepository((
            db: dynamoDB,
            tableName: "penny-bot-table",
            eventLoop: awsClient.eventLoopGroup.next(),
            logger: logger
        ))
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
                localUser = try await userRepo.getUser(discord: user.userID)
            case .github:
                localUser = try await userRepo.getUser(github: user.userID)
            case .penny:
                throw ServiceError.unimplemented()
            }
        }
        catch let error {
            logger.error("Can't add coins", metadata: ["error": "\(error)"])
            throw ServiceError.failedToUpdate
        }
        
        if var localUser {
            let dbUser = DynamoDBUser(user: localUser, type: .discord)
            
            try await userRepo.updateUser(dbUser, coinEntry: coinEntry)
            return CoinResponse(
                sender: fromDiscordID,
                receiver: localUser.userID,
                coins: localUser.numberOfCoins
            )
        } else {
            let localUser = try await insertIntoDB(user: user, with: coinEntry)
            return CoinResponse(
                sender: fromDiscordID,
                receiver: localUser.userID,
                coins: localUser.numberOfCoins
            )
        }
    }
    
    public func getUserUUID(from user: User, with source: CoinEntrySource) async throws -> UUID {
        var localUser: User?
        
        do {
            switch source {
            case .discord:
                localUser = try await userRepo.getUser(discord: user.userID)
            case .github:
                localUser = try await userRepo.getUser(github: user.userID)
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
    
    private func insertIntoDB(user: User, with coinEntry: CoinEntry) async throws -> User {
        let dbUser = DynamoDBUser(user: user, type: .discord)
        try await userRepo.insertUser(dbUser, coinEntry: coinEntry)
        var user = user
        user.numberOfCoins += coinEntry.amount
        return user
    }
}
