import Foundation

// MARK: - PullRequest
struct PullRequest: Codable {
    let activeLockReason: String?
    let additions: Int
    let assignee: User?
    let assignees: [User]?
    /// How the author is associated with the repository.
    let authorAssociation: AuthorAssociation
    /// The status of auto merging a pull request.
    let autoMerge: AutoMerge?
    let base: Base
    let body: String?
    let changedFiles: Int
    let closedAt: Date?
    let comments: Int
    let commentsURL: String
    let commits: Int
    let commitsURL: String
    let createdAt: Date
    let deletions: Int
    let diffURL: String
    /// Indicates whether or not the pull request is a draft.
    let draft: Bool?
    let head: Head
    let htmlURL: String
    let id: Int
    let issueURL: String
    let labels: [Label]
    let locked: Bool
    /// Indicates whether maintainers can modify the pull request.
    let maintainerCanModify: Bool
    let mergeCommitSHA: String?
    let mergeable: Bool?
    let mergeableState: String
    let merged: Bool
    let mergedAt: Date?
    let mergedBy: User?
    let milestone: Milestone?
    let nodeID: String
    /// Number uniquely identifying the pull request within its repository.
    let number: Int
    let patchURL: String
    let rebaseable: Bool?
    let requestedReviewers: [User]?
    let requestedTeams: [Team]?
    let reviewCommentURL: String
    let reviewComments: Int
    let reviewCommentsURL: String
    /// State of this Pull Request. Either `open` or `closed`.
    let state: State
    let statusesURL: String
    /// The title of the pull request.
    let title: String
    let updatedAt: Date
    let url: String
    /// A GitHub user.
    let user: User

    enum CodingKeys: String, CodingKey {
        case activeLockReason = "active_lock_reason"
        case additions, assignee, assignees
        case authorAssociation = "author_association"
        case autoMerge = "auto_merge"
        case base, body
        case changedFiles = "changed_files"
        case closedAt = "closed_at"
        case comments
        case commentsURL = "comments_url"
        case commits
        case commitsURL = "commits_url"
        case createdAt = "created_at"
        case deletions
        case diffURL = "diff_url"
        case draft, head
        case htmlURL = "html_url"
        case id
        case issueURL = "issue_url"
        case labels, locked
        case maintainerCanModify = "maintainer_can_modify"
        case mergeCommitSHA = "merge_commit_sha"
        case mergeable
        case mergeableState = "mergeable_state"
        case merged
        case mergedAt = "merged_at"
        case mergedBy = "merged_by"
        case milestone
        case nodeID = "node_id"
        case number
        case patchURL = "patch_url"
        case rebaseable
        case requestedReviewers = "requested_reviewers"
        case requestedTeams = "requested_teams"
        case reviewCommentURL = "review_comment_url"
        case reviewComments = "review_comments"
        case reviewCommentsURL = "review_comments_url"
        case state
        case statusesURL = "statuses_url"
        case title
        case updatedAt = "updated_at"
        case url, user
    }

    // MARK: - AutoMerge
    struct AutoMerge: Codable {
        /// Commit message for the merge commit.
        let commitMessage: String
        /// Title for the merge commit message.
        let commitTitle: String
        /// A GitHub user.
        let enabledBy: User
        /// The merge method to use.
        let mergeMethod: MergeMethod

        enum CodingKeys: String, CodingKey {
            case commitMessage = "commit_message"
            case commitTitle = "commit_title"
            case enabledBy = "enabled_by"
            case mergeMethod = "merge_method"
        }

        /// The merge method to use.
        enum MergeMethod: String, Codable {
            case merge = "merge"
            case rebase = "rebase"
            case squash = "squash"
        }
    }

    enum State: String, Codable {
        case closed = "closed"
        case stateOpen = "open"
    }
}

// MARK: - Action
extension PullRequest {
    enum Action: String, Codable {
        case assigned
        case auto_merge_disabled
        case auto_merge_enabled
        case closed
        case converted_to_draft
        case demilestoned
        case dequeued
        case edited
        case enqueued
        case labeled
        case locked
        case milestoned
        case opened
        case ready_for_review
        case reopened
        case review_request_removed
        case review_requested
        case synchronize
        case unassigned
        case unlabeled
        case unlocked
    }
}

// MARK: - Base
struct Base: Codable {
    let label, ref, sha: String
    let user: User
    let repo: Repository
}

// MARK: - Comments
struct Comments: Codable {
    let href: String
}

/// How the author is associated with the repository.
enum AuthorAssociation: String, Codable {
    case collaborator = "COLLABORATOR"
    case contributor = "CONTRIBUTOR"
    case firstTimeContributor = "FIRST_TIME_CONTRIBUTOR"
    case firstTimer = "FIRST_TIMER"
    case mannequin = "MANNEQUIN"
    case member = "MEMBER"
    case none = "NONE"
    case owner = "OWNER"
}

// MARK: - Head
struct Head: Codable {
    let label, ref: String
    let repo: Repository?
    let sha: String
    let user: User
}
