import Foundation
import PennyModels
import PennyRepositories

public struct FakeUserRepository: UserRepository {
    
    public init() { }
    
    public func insertUser(_ user: DynamoDBUser) async throws -> Void { }
    
    public func updateUser(_ user: DynamoDBUser) async throws -> Void { }
    
    public func getUser(discord id: String) async throws -> User? {
        User(
            id: UUID(),
            discordID: id,
            githubID: nil,
            numberOfCoins: .random(in: 0..<10_000),
            coinEntries: [],
            createdAt: Date().addingTimeInterval(-.random(in: 0..<Double(1 << 30)))
        )
    }
    
    public func getUser(github id: String) async throws -> User? {
        User(
            id: UUID(),
            discordID: nil,
            githubID: id,
            numberOfCoins: .random(in: 0..<10_000),
            coinEntries: [],
            createdAt: Date().addingTimeInterval(-.random(in: 0..<Double(1 << 30)))
        )
    }
    
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
