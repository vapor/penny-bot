import Foundation
import AWSLambdaRuntimeCore
import SotoCore
import SotoDynamoDB
import AsyncHTTPClient

struct UserService {
    enum ServiceError: Error {
        case failedToUpdate
    }
    
    let logger: Logger
    let userRepo: DynamoUserRepository
    
    init(_ awsClient: AWSClient, _ logger: Logger) {
        let euWest = Region(awsRegionName: "eu-west-2")
        //let endpoint = ProcessInfo.processInfo.environment["DynamoDBEndpointScript"]
        let dynamoDB = DynamoDB(client: awsClient, region: euWest/*, endpoint: endpoint*/)
        self.logger = logger
        self.userRepo = DynamoUserRepository(db: dynamoDB, tableName: "penny-bot-table", eventLoop: awsClient.eventLoopGroup.next(), logger: logger)
    }
    
    func addCoins(with coinEntry: CoinEntry, to user: User) async throws -> String {
        var localUser: User
                
        switch coinEntry.source {
        case .discord:
            do {
                localUser = try await userRepo.getUser(discord: user.discordID!)
                
                localUser.addCoinEntry(coinEntry)
                
                let dbUser = DynamoDBUser(user: localUser)
                
                print("User after update \(dbUser)")
                try await userRepo.updateUser(dbUser)
            }
            catch DBError.itemNotFound {
                localUser = try await insertIntoDB(user: user, with: coinEntry)
            }
            catch let error {
                logger.error("\(error.localizedDescription)")
                throw ServiceError.failedToUpdate
            }
            
            return "\(localUser.discordID!) has \(localUser.numberOfCoins) coins."
            
        case .github:
            print("TO BE IMPLEMENTED")
            return ""
            
            
            
        case .penny:
            print("TO BE IMPLEMENTED")
            return ""
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
