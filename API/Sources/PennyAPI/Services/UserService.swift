import Foundation
import AWSLambdaRuntimeCore
import SotoCore
import SotoDynamoDB
import AsyncHTTPClient

struct UserService {
    enum ServiceError: Error {
        case noUserFound
    }
    
    let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
    let awsClient = AWSClient(
        credentialProvider: .static(accessKeyId: "sdm", secretAccessKey: "sdf;kesfe"),
        httpClientProvider: .createNew
    )
    let logger: Logger
    let eventLoop: EventLoop
    
    let userRepo: DynamoUserRepository
    
    init(_ eventLoop: EventLoop, _ logger: Logger) {
        let euWest = Region(awsRegionName: "eu-west-2")
        let dynamoDB = DynamoDB(client: awsClient, region: euWest)
        self.eventLoop = eventLoop
        self.logger = logger
        self.userRepo = DynamoUserRepository(db: dynamoDB, tableName: "penny-bot-table", eventLoop: eventLoop, logger: logger)
    }
    
    func addCoins(with coinEntry: CoinEntry, to user: User) async throws -> String {
        var localUser: User
        
        switch coinEntry.source {
        case .discord:
            do {
                localUser = try await userRepo.getUser(discord: user.discordID!)
                
                localUser.addCoinEntry(coinEntry)
                
                let dbUser = DynamoDBUser(user: localUser)
                try await userRepo.updateUser(dbUser)
            }
            catch {
                localUser = user
                
                localUser.addCoinEntry(coinEntry)
                
                let dbUser = DynamoDBUser(user: localUser)
                try await userRepo.insertUser(dbUser)
            }
            
            return "\(localUser.discordID!) has \(localUser.numberOfCoins) coins."
            
        case .github:
            return ""
            
            
            
        case .penny:
            print("TO BE IMPLEMENTED")
            return ""
        }
    }
}
