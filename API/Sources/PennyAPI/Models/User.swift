import Foundation

struct User: Codable {
    let id: UUID
    let discordID: String?
    let githubID: String?
    var numberOfCoins: Int
    var coinEntries: [CoinEntry]
    let createdAt: Date
    
    mutating func addCoinEntry(_ entry: CoinEntry) {
        coinEntries.append(entry)
        numberOfCoins += entry.amount
    }
}
