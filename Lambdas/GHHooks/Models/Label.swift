
// MARK: - Label
struct Label: Codable {
    let id: Int
    let nodeID: String?
    let url: String
    let name, color: String
    let labelDefault: Bool?
    let description: String

    enum CodingKeys: String, CodingKey {
        case id
        case nodeID
        case url, name, color
        case labelDefault
        case description
    }
}
