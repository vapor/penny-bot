
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
