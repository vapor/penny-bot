import Foundation

struct GithubEvent: Codable {
    /// Name will be populated after decode
    public var name: String!
    public var action: String?
    public var sender: User
    public var repository: Repository
    public var organization: Organization
}
