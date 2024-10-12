#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// https://docs.github.com/en/webhooks-and-events/webhooks/webhook-events-and-payloads
package struct GHEvent: Sendable, Codable {
    package let action: String?
    package let sender: User
    package let repository: Repository?
    package let organization: Organization?

    package let issue: Issue?
    package let label: Label?
    package let number: Int?
    package let changes: Changes?
    package let pull_request: PullRequest?
    package let release: Release?
    package let before: String?
    package let after: String?
    package let base_ref: String?
    package let compare: String?
    package let created: Bool?
    package let deleted: Bool?
    package let forced: Bool?
    package let commits: [SimpleCommit]?
    package let head_commit: SimpleCommit?
    package let installation: Installation?
    package let pusher: Committer?
    package let ref: String?
    package let enterprise: Enterprise?
}

extension GHEvent {
    /// https://docs.github.com/en/webhooks-and-events/webhooks/webhook-events-and-payloads
    package enum Kind: String, Sendable, Codable {
        case branch_protection_rule
        case check_run
        case check_suite
        case code_scanning_alert
        case commit_comment
        case create
        case delete
        case dependabot_alert
        case deploy_key
        case deployment
        case deployment_protection_rule
        case deployment_status
        case discussion
        case discussion_comment
        case fork
        case github_app_authorization
        case gollum
        case installation
        case installation_repositories
        case installation_target
        case issue_comment
        case issues
        case label
        case marketplace_purchase
        case member
        case membership
        case merge_group
        case meta
        case milestone
        case org_block
        case organization
        case package
        case page_build
        case personal_access_token_request
        case ping
        case project_card
        case project
        case project_column
        case projects_v2
        case projects_v2_item
        case `public`
        case pull_request
        case pull_request_review_comment
        case pull_request_review
        case pull_request_review_thread
        case push
        case registry_package
        case release
        case repository_advisory
        case repository
        case repository_dispatch
        case repository_import
        case repository_vulnerability_alert
        case secret_scanning_alert
        case secret_scanning_alert_location
        case security_advisory
        case security_and_analysis
        case sponsorship
        case star
        case status
        case team_add
        case team
        case watch
        case workflow_dispatch
        case workflow_job
        case workflow_run
    }
}
