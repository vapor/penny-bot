import Foundation
import PennyModels

public protocol UserRepository {
    
    // MARK: - Insert
    func insertUser(_ user: DynamoDBUser) async throws -> Void
    func updateUser(_ user: DynamoDBUser) async throws -> Void
    
    // MARK: - Retrieve
    func getUser(discord id: String) async throws -> User
    func getUser(github id: String) async throws -> User
    
    // MARK: - Link users
    func linkGithub(with discordId: String, _ githubId: String) async throws -> String
    func linkDiscord(with githubId: String, _ discordId: String) async throws -> String
}
