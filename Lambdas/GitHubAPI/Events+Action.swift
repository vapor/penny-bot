extension PullRequest {
    /// https://docs.github.com/en/webhooks-and-events/webhooks/webhook-events-and-payloads#pull_request
    package enum Action: String, Codable {
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
    package enum Action: String, Sendable, Codable {
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
        case typed  // undocumented?
        case unassigned
        case unlabeled
        case unlocked
        case unpinned
    }
}

extension Release {
    /// https://docs.github.com/en/webhooks-and-events/webhooks/webhook-events-and-payloads#release
    package enum Action: String, Codable {
        case created
        case deleted
        case edited
        case prereleased
        case published
        case released
        case unpublished
    }
}
