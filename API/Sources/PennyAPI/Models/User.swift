import Foundation

struct User: Codable {
    let id: UUID
    let discordID: String?
    let githubID: String?
    let numberOfCoins: Int
    let coinEntries: [CoinEntry]
    let createdAt: Date
}
