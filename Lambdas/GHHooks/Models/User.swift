import Foundation

// MARK: - User
struct User: Codable {
    let avatarURL: String
    let bio, blog: String?
    let businessPlus: Bool?
    let collaborators: Int?
    let company: String?
    let createdAt: Date
    let diskUsage: Int?
    let email: String?
    let eventsURL: String
    let followers: Int
    let followersURL: String
    let following: Int
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
    let publicGists, publicRepos: Int
    let receivedEventsURL, reposURL: String
    let siteAdmin: Bool
    let starredURL, subscriptionsURL: String
    let suspendedAt: Date?
    let totalPrivateRepos: Int?
    let twitterUsername: String?
    let twoFactorAuthentication: Bool?
    let type: String
    let updatedAt: Date
    let url: String

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case bio, blog
        case businessPlus
        case collaborators, company
        case createdAt
        case diskUsage
        case email
        case eventsURL
        case followers
        case followersURL
        case following
        case followingURL
        case gistsURL
        case gravatarID
        case hireable
        case htmlURL
        case id
        case ldapDN
        case location, login, name
        case nodeID
        case organizationsURL
        case ownedPrivateRepos
        case plan
        case privateGists
        case publicGists
        case publicRepos
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredURL
        case subscriptionsURL
        case suspendedAt
        case totalPrivateRepos
        case twitterUsername
        case twoFactorAuthentication
        case type
        case updatedAt
        case url
    }

    // MARK: - Plan
    struct Plan: Codable {
        let collaborators: Int
        let name: String
        let privateRepos, space: Int

        enum CodingKeys: String, CodingKey {
            case collaborators, name
            case privateRepos
            case space
        }
    }
}
