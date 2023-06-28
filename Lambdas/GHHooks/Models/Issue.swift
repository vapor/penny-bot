import Foundation

// MARK: - Issue
struct Issue: Codable {
    let url: String
    let repositoryURL: String?
    let labelsURL: String?
    let commentsURL: String?
    let eventsURL: String?
    let htmlURL: String?
    let id: Int
    let nodeID: String?
    let number: Int
    let title: String
    let user: User
    let labels: [Label]
    let state: String
    let locked: Bool
    let assignee: String?
    /// This is probably not `String`
    let assignees: [String]
    let milestone: String?
    let comments: Int
    let createdAt, updatedAt: Date?
    let closedAt: Date?
    let authorAssociation: String?
    let activeLockReason: String?
    let body: String
    let reactions: Reactions
    let timelineURL: String?
    let performedViaGithubApp: Bool?
    let stateReason: String?

    enum CodingKeys: String, CodingKey {
        case url
        case repositoryURL
        case labelsURL
        case commentsURL
        case eventsURL
        case htmlURL
        case id
        case nodeID
        case number, title, user, labels, state, locked, assignee, assignees, milestone, comments
        case createdAt
        case updatedAt
        case closedAt
        case authorAssociation
        case activeLockReason
        case body, reactions
        case timelineURL
        case performedViaGithubApp
        case stateReason
    }
}

extension Issue {
    enum Action: String, Codable {
        case assigned
        case closed
        case deleted
        case demilestoned
        case edited
        case labeled
        case locked
        case milestoned
        case opened
        case pinned
        case reopened
        case transferred
        case unassigned
        case unlabeled
        case unlocked
        case unpinned
    }
}
