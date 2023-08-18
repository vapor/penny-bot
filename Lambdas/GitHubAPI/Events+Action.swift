
extension PullRequest {
    /// https://docs.github.com/en/webhooks-and-events/webhooks/webhook-events-and-payloads#pull_request
    public enum Action: String, Codable {
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
        case submitted
    }
}

extension Issue {
    /// https://docs.github.com/en/webhooks-and-events/webhooks/webhook-events-and-payloads#issues
    public enum Action: String, Sendable, Codable {
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

extension Release {
    /// https://docs.github.com/en/webhooks-and-events/webhooks/webhook-events-and-payloads#release
    public enum Action: String, Codable {
        case created
        case deleted
        case edited
        case prereleased
        case published
        case released
        case unpublished
    }
}
