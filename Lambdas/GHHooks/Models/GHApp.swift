import Foundation

// MARK: - GitHubApp
struct GHApp: Codable {
    let clientID, clientSecret: String?
    let createdAt: Date
    let description: String?
    /// The list of events for the GitHub app
    let events: [String]
    let externalURL, htmlURL: String
    /// Unique identifier of the GitHub app
    let id: Int
    /// The number of installations associated with the GitHub app
    let installationsCount: Int?
    /// The name of the GitHub app
    let name: String
    let nodeID: String
    let owner: User?
    let pem: String?
    /// The set of permissions for the GitHub app
    let permissions: [String: String]
    /// The slug name of the GitHub app
    let slug: String?
    let updatedAt: Date
    let webhookSecret: String?

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case clientSecret = "client_secret"
        case createdAt = "created_at"
        case description, events
        case externalURL = "external_url"
        case htmlURL = "html_url"
        case id
        case installationsCount = "installations_count"
        case name
        case nodeID = "node_id"
        case owner, pem, permissions, slug
        case updatedAt = "updated_at"
        case webhookSecret = "webhook_secret"
    }
}
