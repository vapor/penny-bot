import Foundation
import SotoCore
import SotoDynamoDB
import PennyRepositories
import PennyModels

public struct UserService {
    
    public enum ServiceError: Error {
        case failedToUpdate
        case unimplemented
    }
    
    let logger: Logger
    let userRepo: DynamoUserRepository
    
    public init(_ awsClient: AWSClient, _ logger: Logger) {
        let euWest = Region(awsRegionName: "eu-west-1")
        //let endpoint = ProcessInfo.processInfo.environment["DynamoDBEndpointScript"]
        let dynamoDB = DynamoDB(client: awsClient, region: euWest/*, endpoint: endpoint*/)
        self.logger = logger
        self.userRepo = DynamoUserRepository(db: dynamoDB, tableName: "penny-bot-table", eventLoop: awsClient.eventLoopGroup.next(), logger: logger)
    }
    
    public func addCoins(with coinEntry: CoinEntry, to user: User) async throws -> CoinResponse {
        var localUser: User
        
        do {
            switch coinEntry.source {
            case .discord:
                localUser = try await userRepo.getUser(discord: user.discordID!)
            case .github:
                localUser = try await userRepo.getUser(github: user.githubID!)
            case .penny:
                throw ServiceError.unimplemented
            }
            
            localUser.addCoinEntry(coinEntry)
            let dbUser = DynamoDBUser(user: localUser)
                
            try await userRepo.updateUser(dbUser)
            return CoinResponse(
                sender: coinEntry.from.discordID,
                receiver: localUser.discordID!,
                coins: localUser.numberOfCoins
            )
        }
        catch DBError.itemNotFound {
            localUser = try await insertIntoDB(user: user, with: coinEntry)
            return CoinResponse(
                sender: coinEntry.from.discordID,
                receiver: localUser.discordID!,
                coins: localUser.numberOfCoins
            )
        }
        catch let error {
            logger.error("\(error.localizedDescription)")
            throw ServiceError.failedToUpdate
        }
    }
    
    public func getUserUUID(from user: User, with source: CoinEntrySource) async throws -> UUID {
        var localUser: User
        
        do {
            switch source {
            case .discord:
                localUser = try await userRepo.getUser(discord: user.discordID!)
            case .github:
                localUser = try await userRepo.getUser(github: user.githubID!)
            case .penny:
                abort()
            }
            
            return localUser.id
        }
        catch {
            return UUID()
        }
    }
    
    private func insertIntoDB(user account: User, with coinEntry: CoinEntry) async throws -> User{
        var localUser = account
        
        localUser.addCoinEntry(coinEntry)
        
        let dbUser = DynamoDBUser(user: localUser)
        try await userRepo.insertUser(dbUser)
        
        return localUser
    }
}
