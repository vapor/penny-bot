
/// Groups of organization members that gives permissions on specified repositories.
// MARK: - Team
struct Team: Codable {
    /// Description of the team
    let description: String?
    let htmlURL: String
    /// Unique identifier of the team
    let id: Int
    /// Distinguished Name (DN) that team maps to within LDAP environment
    let ldapDN: String?
    let membersURL: String
    /// Name of the team
    let name: String
    let nodeID: String
    /// The notification setting the team has set
    let notificationSetting: String?
    /// Permission that the team will have for its repositories
    let permission: String
    /// The level of privacy this team should have
    let privacy: String?
    let repositoriesURL, slug: String
    /// URL for the team
    let url: String

    enum CodingKeys: String, CodingKey {
        case description
        case htmlURL = "html_url"
        case id
        case ldapDN = "ldap_dn"
        case membersURL = "members_url"
        case name
        case nodeID = "node_id"
        case notificationSetting = "notification_setting"
        case permission, privacy
        case repositoriesURL = "repositories_url"
        case slug, url
    }
}
