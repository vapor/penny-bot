
// MARK: - Reactions
struct Reactions: Codable {
    let url: String
    let totalCount: Int?
    let the1: Int?
    let reactions1: Int?
    let laugh: Int?
    let hooray: Int?
    let confused: Int?
    let heart: Int?
    let rocket: Int?
    let eyes: Int?

    enum CodingKeys: String, CodingKey {
        case url
        case totalCount
        case the1
        case reactions1
        case laugh, hooray, confused, heart, rocket, eyes
    }
}
