import Foundation

/// A collection of related issues and pull requests.
// MARK: - Milestone
struct Milestone: Codable {
    let closedAt: Date?
    let closedIssues: Int
    let createdAt: Date
    let creator: User?
    let description: String?
    let dueOn: Date?
    let htmlURL: String
    let id: Int
    let labelsURL, nodeID: String
    /// The number of the milestone.
    let number: Int
    let openIssues: Int
    /// The state of the milestone.
    let state: PullRequest.State
    /// The title of the milestone.
    let title: String
    let updatedAt: Date
    let url: String

    enum CodingKeys: String, CodingKey {
        case closedAt = "closed_at"
        case closedIssues = "closed_issues"
        case createdAt = "created_at"
        case creator, description
        case dueOn = "due_on"
        case htmlURL = "html_url"
        case id
        case labelsURL = "labels_url"
        case nodeID = "node_id"
        case number
        case openIssues = "open_issues"
        case state, title
        case updatedAt = "updated_at"
        case url
    }
}
