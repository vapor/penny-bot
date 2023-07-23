import DiscordModels
import Models

protocol CoinService: Sendable {
    func postCoin(with coinRequest: UserRequest.DiscordCoinEntry) async throws -> CoinResponse
    func getCoinCount(of discordID: UserSnowflake) async throws -> Int
    func getGitHubName(of discordID: UserSnowflake) async throws -> GitHubUserResponse
}
