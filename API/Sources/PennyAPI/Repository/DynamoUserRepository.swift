import Foundation
import SotoDynamoDB

enum APIError: Error {
    case invalidItem
    case tableNameNotFound
    case invalidRequest
    case invalidHandler
}

struct DynamoUserRepository: UserRepository {
    
    // Mark: - Properties
    let db: DynamoDB
    let tableName: String
    
    init(db: DynamoDB, tableName: String) {
        self.db = db
        self.tableName = tableName
    }
    
    func insertUser(_ user: DynamoDBUser) async throws -> Task {
        // TODO: Implement
    }
    
    func updateUser(_ user: DynamoDBUser) async throws -> Task {
        // TODO: Implement
    }
    
    func getUser(with discordId: String) async throws -> Task {
        // TODO: Implement
    }
    
    func getUser(with githubId: String) async throws -> Task {
        // TODO: Implement
    }
    
    func linkGithub(with discordId: String, _ githubId: String) async throws -> Task {
        // TODO: Implement
    }
    
    func linkDiscord(with githubId: String, _ discordId: String) async throws -> Task {
        // TODO: Implement
    }
}
