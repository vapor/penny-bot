import Foundation

// MARK: - User
struct User: Codable {
    let avatarURL: String
    let bio, blog: String?
    let businessPlus: Bool?
    let collaborators: Int?
    let company: String?
    let createdAt: Date?
    let diskUsage: Int?
    let email: String?
    let eventsURL: String
    let followers: Int?
    let followersURL: String
    let following: Int?
    let followingURL, gistsURL: String
    let gravatarID: String?
    let hireable: Bool?
    let htmlURL: String
    let id: Int
    let ldapDN: String?
    let location: String?
    let login: String
    let name: String?
    let nodeID, organizationsURL: String
    let ownedPrivateRepos: Int?
    let plan: Plan?
    let privateGists: Int?
    let publicGists: Int?
    let publicRepos: Int?
    let receivedEventsURL, reposURL: String
    let siteAdmin: Bool
    let starredURL, subscriptionsURL: String
    let suspendedAt: Date?
    let totalPrivateRepos: Int?
    let twitterUsername: String?
    let twoFactorAuthentication: Bool?
    let type: String
    let updatedAt: Date?
    let url: String

    enum CodingKeys: String, CodingKey {
        case avatarURL = "avatar_url"
        case bio, blog
        case businessPlus = "business_plus"
        case collaborators, company
        case createdAt = "created_at"
        case diskUsage = "disk_usage"
        case email
        case eventsURL = "events_url"
        case followers
        case followersURL = "followers_url"
        case following
        case followingURL = "following_url"
        case gistsURL = "gists_url"
        case gravatarID = "gravatar_id"
        case hireable
        case htmlURL = "html_url"
        case id
        case ldapDN = "ldap_dn"
        case location, login, name
        case nodeID = "node_id"
        case organizationsURL = "organizations_url"
        case ownedPrivateRepos = "owned_private_repos"
        case plan
        case privateGists = "private_gists"
        case publicGists = "public_gists"
        case publicRepos = "public_repos"
        case receivedEventsURL = "received_events_url"
        case reposURL = "repos_url"
        case siteAdmin = "site_admin"
        case starredURL = "starred_url"
        case subscriptionsURL = "subscriptions_url"
        case suspendedAt = "suspended_at"
        case totalPrivateRepos = "total_private_repos"
        case twitterUsername = "twitter_username"
        case twoFactorAuthentication = "two_factor_authentication"
        case type
        case updatedAt = "updated_at"
        case url
    }

    struct Plan: Codable {
        let collaborators: Int
        let name: String
        let privateRepos, space: Int

        enum CodingKeys: String, CodingKey {
            case collaborators, name
            case privateRepos = "private_repos"
            case space
        }
    }
}
