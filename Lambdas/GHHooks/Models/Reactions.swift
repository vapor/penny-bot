
// MARK: - Reactions
struct Reactions: Codable {
    let the1, reactionRollup1, confused, eyes: Int
    let heart, hooray, laugh, rocket: Int
    let totalCount: Int
    let url: String

    enum CodingKeys: String, CodingKey {
        case the1 = "+1"
        case reactionRollup1 = "-1"
        case confused, eyes, heart, hooray, laugh, rocket
        case totalCount = "total_count"
        case url
    }
}
