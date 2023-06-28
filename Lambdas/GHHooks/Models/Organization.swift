import Foundation

/// Organization Full
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
    let createdAt: Date
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
    let followers, following: Int
    let hasOrganizationProjects, hasRepositoryProjects: Bool
    let hooksURL, htmlURL: String
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
    let publicGists: Int
    let publicMembersURL: String
    let publicRepos: Int
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
    let type: String
    let updatedAt: Date
    let url: String
    let webCommitSignoffRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case advancedSecurityEnabledForNewRepositories
        case avatarURL
        case billingEmail
        case blog, collaborators, company
        case createdAt
        case defaultRepositoryPermission
        case dependabotAlertsEnabledForNewRepositories
        case dependabotSecurityUpdatesEnabledForNewRepositories
        case dependencyGraphEnabledForNewRepositories
        case description
        case diskUsage
        case email
        case eventsURL
        case followers, following
        case hasOrganizationProjects
        case hasRepositoryProjects
        case hooksURL
        case htmlURL
        case id
        case isVerified
        case issuesURL
        case location, login
        case membersAllowedRepositoryCreationType
        case membersCanCreateInternalRepositories
        case membersCanCreatePages
        case membersCanCreatePrivatePages
        case membersCanCreatePrivateRepositories
        case membersCanCreatePublicPages
        case membersCanCreatePublicRepositories
        case membersCanCreateRepositories
        case membersCanForkPrivateRepositories
        case membersURL
        case name
        case nodeID
        case ownedPrivateRepos
        case plan
        case privateGists
        case publicGists
        case publicMembersURL
        case publicRepos
        case reposURL
        case secretScanningEnabledForNewRepositories
        case secretScanningPushProtectionCustomLink
        case secretScanningPushProtectionCustomLinkEnabled
        case secretScanningPushProtectionEnabledForNewRepositories
        case totalPrivateRepos
        case twitterUsername
        case twoFactorRequirementEnabled
        case type
        case updatedAt
        case url
        case webCommitSignoffRequired
    }

    // MARK: - Plan
    struct Plan: Codable {
        let filledSeats: Int?
        let name: String
        let privateRepos: Int
        let seats: Int?
        let space: Int

        enum CodingKeys: String, CodingKey {
            case filledSeats
            case name
            case privateRepos
            case seats, space
        }
    }
}
