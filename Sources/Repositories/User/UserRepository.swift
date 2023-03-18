import Models

public protocol UserRepository {
    
    // MARK: - Insert
    func insertUser(_ user: DynamoDBUser) async throws
    func updateUser(_ user: DynamoDBUser) async throws
    
    // MARK: - Retrieve
    
    /// Returns nil if user does not exist.
    func getUser(discord id: String) async throws -> LambdaUser?
    /// Returns nil if user does not exist.
    func getUser(github id: String) async throws -> LambdaUser?
    
    // MARK: - Link users
    func linkGithub(with discordId: String, _ githubId: String) async throws -> String
    func linkDiscord(with githubId: String, _ discordId: String) async throws -> String
}
