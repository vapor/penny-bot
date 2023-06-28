import Foundation

// MARK: - User
struct User: Codable {
    let login: String
    let id: Int
    let nodeID: String?
    let avatarURL: String?
    let gravatarID: String?
    let url: String
    let htmlURL: String?
    let followersURL: String?
    let followingURL: String?
    let gistsURL: String?
    let starredURL: String?
    let subscriptionsURL: String?
    let organizationsURL: String?
    let reposURL: String?
    let eventsURL: String?
    let receivedEventsURL: String?
    let type: String
    let siteAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case login, id
        case nodeID
        case avatarURL
        case gravatarID
        case url
        case htmlURL
        case followersURL
        case followingURL
        case gistsURL
        case starredURL
        case subscriptionsURL
        case organizationsURL
        case reposURL
        case eventsURL
        case receivedEventsURL
        case type
        case siteAdmin
    }
}
