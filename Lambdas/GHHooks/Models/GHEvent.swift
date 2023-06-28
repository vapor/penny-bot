import Foundation

struct GHEvent: Codable {
    /// Name will be populated after decode
    var name: Kind!
    let action: String?
    let sender: User
    let repository: Repository
    let organization: Organization

    let issue: Issue?
    let label: Label?

    let number: Int?
    let pullRequest: PullRequest?
    let before: String?
    let after: String?
}

extension GHEvent {
    enum Kind: String, Codable {
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
