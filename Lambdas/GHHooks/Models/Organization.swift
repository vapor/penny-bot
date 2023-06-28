import Foundation

// MARK: - Organization
struct Organization: Codable {
    let login: String
    let id: Int
    let nodeID: String?
    let url: String
    let reposURL: String?
    let eventsURL: String?
    let hooksURL: String?
    let issuesURL: String?
    let membersURL: String?
    let publicMembersURL: String?
    let avatarURL: String?
    let description: String

    enum CodingKeys: String, CodingKey {
        case login, id
        case nodeID
        case url
        case reposURL
        case eventsURL
        case hooksURL
        case issuesURL
        case membersURL
        case publicMembersURL
        case avatarURL
        case description
    }
}
