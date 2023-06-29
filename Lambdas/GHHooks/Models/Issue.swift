import Foundation

// MARK: - Issue
struct Issue: Codable {
    let activeLockReason: String?
    let assignee: User?
    let assignees: [User]?
    /// How the author is associated with the repository.
    let authorAssociation: AuthorAssociation
    /// Contents of the issue
    let body: String?
    let bodyHTML, bodyText: String?
    let closedAt: Date?
    let closedBy: User?
    let comments: Int
    let commentsURL: String
    let createdAt: Date
    let draft: Bool?
    let eventsURL, htmlURL: String
    let id: Int
    /// Labels to associate with this issue; pass one or more label names to replace the set of
    /// labels on this issue; send an empty array to clear all labels from the issue; note that
    /// the labels are silently dropped for users without push access to the repository
    let labels: [Label]
    let labelsURL: String
    let locked: Bool
    let milestone: Milestone?
    let nodeID: String
    /// Number uniquely identifying the issue within its repository
    let number: Int
    let performedViaGithubApp: GHApp?
    let pullRequest: PullRequest?
    let reactions: Reactions?
    /// A repository on GitHub.
    let repository: Repository?
    let repositoryURL: String
    /// State of the issue; either 'open' or 'closed'
    let state: String
    /// The reason for the current state
    let stateReason: StateReason?
    let timelineURL: String?
    /// Title of the issue
    let title: String
    let updatedAt: Date
    /// URL for the issue
    let url: String
    let user: User?

    enum CodingKeys: String, CodingKey {
        case activeLockReason = "active_lock_reason"
        case assignee, assignees
        case authorAssociation = "author_association"
        case body
        case bodyHTML = "body_html"
        case bodyText = "body_text"
        case closedAt = "closed_at"
        case closedBy = "closed_by"
        case comments
        case commentsURL = "comments_url"
        case createdAt = "created_at"
        case draft
        case eventsURL = "events_url"
        case htmlURL = "html_url"
        case id, labels
        case labelsURL = "labels_url"
        case locked, milestone
        case nodeID = "node_id"
        case number
        case performedViaGithubApp = "performed_via_github_app"
        case pullRequest = "pull_request"
        case reactions, repository
        case repositoryURL = "repository_url"
        case state
        case stateReason = "state_reason"
        case timelineURL = "timeline_url"
        case title
        case updatedAt = "updated_at"
        case url, user
    }

    enum StateReason: String, Codable {
        case completed = "completed"
        case notPlanned = "not_planned"
        case reopened = "reopened"
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
