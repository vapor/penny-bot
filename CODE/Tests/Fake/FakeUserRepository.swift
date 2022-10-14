import Foundation
import SotoDynamoDB
import PennyModels
import PennyExtensions
import PennyRepositories

public struct FakeUserRepository: UserRepository {
    
    // MARK: - Properties
    let db: DynamoDB
    let tableName: String
    let eventLoop: EventLoop
    let logger: Logger
    
    public init(db: DynamoDB, tableName: String, eventLoop: EventLoop, logger: Logger) {
        self.db = db
        self.tableName = tableName
        self.eventLoop = eventLoop
        self.logger = logger
    }
    
    // MARK: - Insert & Update
    public func insertUser(_ user: DynamoDBUser) async throws -> Void { }
    
    public func updateUser(_ user: DynamoDBUser) async throws -> Void { }
    
    // MARK: - Retrieve
    public func getUser(discord id: String) async throws -> User {
        User(
            id: UUID(),
            discordID: id,
            githubID: nil,
            numberOfCoins: .random(in: 0..<10_000),
            coinEntries: [],
            createdAt: Date().addingTimeInterval(-.random(in: 0..<Double(1 << 30)))
        )
    }
    
    public func getUser(github id: String) async throws -> User {
        User(
            id: UUID(),
            discordID: nil,
            githubID: id,
            numberOfCoins: .random(in: 0..<10_000),
            coinEntries: [],
            createdAt: Date().addingTimeInterval(-.random(in: 0..<Double(1 << 30)))
        )
    }
    
    // MARK: - Link users
    public func linkGithub(with discordId: String, _ githubId: String) async throws -> String {
        abort()
    }
    
    public func linkDiscord(with githubId: String, _ discordId: String) async throws -> String {
        abort()
    }
    
    private func mergeAccounts() async throws -> Bool {
        abort()
    }
    
    private func deleteAccount() async throws -> Bool {
        abort()
    }
}
