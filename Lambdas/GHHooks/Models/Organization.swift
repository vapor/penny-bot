import Foundation

// MARK: - Organization
struct Organization: Codable {
    /// Whether GitHub Advanced Security is enabled for new repositories and repositories
    /// transferred to this organization.
    ///
    /// This field is only visible to organization owners or members of a team with the security
    /// manager role.
    let advancedSecurityEnabledForNewRepositories: Bool?
    let avatarURL: String
    let billingEmail: String?
    let blog: String?
    let collaborators: Int?
    let company: String?
    let createdAt: Date?
    let defaultRepositoryPermission: String?
    /// Whether GitHub Advanced Security is automatically enabled for new repositories and
    /// repositories transferred to
    /// this organization.
    ///
    /// This field is only visible to organization owners or members of a team with the security
    /// manager role.
    let dependabotAlertsEnabledForNewRepositories: Bool?
    /// Whether dependabot security updates are automatically enabled for new repositories and
    /// repositories transferred
    /// to this organization.
    ///
    /// This field is only visible to organization owners or members of a team with the security
    /// manager role.
    let dependabotSecurityUpdatesEnabledForNewRepositories: Bool?
    /// Whether dependency graph is automatically enabled for new repositories and repositories
    /// transferred to this
    /// organization.
    ///
    /// This field is only visible to organization owners or members of a team with the security
    /// manager role.
    let dependencyGraphEnabledForNewRepositories: Bool?
    let description: String?
    let diskUsage: Int?
    let email: String?
    let eventsURL: String
    let followers: Int?
    let following: Int?
    let hasOrganizationProjects, hasRepositoryProjects: Bool?
    let hooksURL: String
    let htmlURL: String?
    let id: Int
    let isVerified: Bool?
    let issuesURL: String
    let location: String?
    let login: String
    let membersAllowedRepositoryCreationType: String?
    let membersCanCreateInternalRepositories, membersCanCreatePages, membersCanCreatePrivatePages, membersCanCreatePrivateRepositories: Bool?
    let membersCanCreatePublicPages, membersCanCreatePublicRepositories: Bool?
    let membersCanCreateRepositories, membersCanForkPrivateRepositories: Bool?
    let membersURL: String
    let name: String?
    let nodeID: String
    let ownedPrivateRepos: Int?
    let plan: Plan?
    let privateGists: Int?
    let publicGists: Int?
    let publicMembersURL: String
    let publicRepos: Int?
    let reposURL: String
    /// Whether secret scanning is automatically enabled for new repositories and repositories
    /// transferred to this
    /// organization.
    ///
    /// This field is only visible to organization owners or members of a team with the security
    /// manager role.
    let secretScanningEnabledForNewRepositories: Bool?
    /// An optional URL string to display to contributors who are blocked from pushing a secret.
    let secretScanningPushProtectionCustomLink: String?
    /// Whether a custom link is shown to contributors who are blocked from pushing a secret by
    /// push protection.
    let secretScanningPushProtectionCustomLinkEnabled: Bool?
    /// Whether secret scanning push protection is automatically enabled for new repositories and
    /// repositories
    /// transferred to this organization.
    ///
    /// This field is only visible to organization owners or members of a team with the security
    /// manager role.
    let secretScanningPushProtectionEnabledForNewRepositories: Bool?
    let totalPrivateRepos: Int?
    let twitterUsername: String?
    let twoFactorRequirementEnabled: Bool?
    let type: String?
    let updatedAt: Date?
    let url: String
    let webCommitSignoffRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case advancedSecurityEnabledForNewRepositories = "advanced_security_enabled_for_new_repositories"
        case avatarURL = "avatar_url"
        case billingEmail = "billing_email"
        case blog, collaborators, company
        case createdAt = "created_at"
        case defaultRepositoryPermission = "default_repository_permission"
        case dependabotAlertsEnabledForNewRepositories = "dependabot_alerts_enabled_for_new_repositories"
        case dependabotSecurityUpdatesEnabledForNewRepositories = "dependabot_security_updates_enabled_for_new_repositories"
        case dependencyGraphEnabledForNewRepositories = "dependency_graph_enabled_for_new_repositories"
        case description
        case diskUsage = "disk_usage"
        case email
        case eventsURL = "events_url"
        case followers, following
        case hasOrganizationProjects = "has_organization_projects"
        case hasRepositoryProjects = "has_repository_projects"
        case hooksURL = "hooks_url"
        case htmlURL = "html_url"
        case id
        case isVerified = "is_verified"
        case issuesURL = "issues_url"
        case location, login
        case membersAllowedRepositoryCreationType = "members_allowed_repository_creation_type"
        case membersCanCreateInternalRepositories = "members_can_create_internal_repositories"
        case membersCanCreatePages = "members_can_create_pages"
        case membersCanCreatePrivatePages = "members_can_create_private_pages"
        case membersCanCreatePrivateRepositories = "members_can_create_private_repositories"
        case membersCanCreatePublicPages = "members_can_create_public_pages"
        case membersCanCreatePublicRepositories = "members_can_create_public_repositories"
        case membersCanCreateRepositories = "members_can_create_repositories"
        case membersCanForkPrivateRepositories = "members_can_fork_private_repositories"
        case membersURL = "members_url"
        case name
        case nodeID = "node_id"
        case ownedPrivateRepos = "owned_private_repos"
        case plan
        case privateGists = "private_gists"
        case publicGists = "public_gists"
        case publicMembersURL = "public_members_url"
        case publicRepos = "public_repos"
        case reposURL = "repos_url"
        case secretScanningEnabledForNewRepositories = "secret_scanning_enabled_for_new_repositories"
        case secretScanningPushProtectionCustomLink = "secret_scanning_push_protection_custom_link"
        case secretScanningPushProtectionCustomLinkEnabled = "secret_scanning_push_protection_custom_link_enabled"
        case secretScanningPushProtectionEnabledForNewRepositories = "secret_scanning_push_protection_enabled_for_new_repositories"
        case totalPrivateRepos = "total_private_repos"
        case twitterUsername = "twitter_username"
        case twoFactorRequirementEnabled = "two_factor_requirement_enabled"
        case type
        case updatedAt = "updated_at"
        case url
        case webCommitSignoffRequired = "web_commit_signoff_required"
    }

    // MARK: - Plan
    struct Plan: Codable {
        let filledSeats: Int?
        let name: String
        let privateRepos: Int
        let seats: Int?
        let space: Int

        enum CodingKeys: String, CodingKey {
            case filledSeats = "filled_seats"
            case name
            case privateRepos = "private_repos"
            case seats, space
        }
    }

}
