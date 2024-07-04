import DiscordModels
import Models

package protocol UsersService: Sendable {
    func getUser(githubID: String) async throws -> DynamoDBUser?
    func postCoin(with coinRequest: UserRequest.CoinEntryRequest) async throws -> CoinResponse
    func getCoinCount(of discordID: UserSnowflake) async throws -> Int
    func linkGitHubID(discordID: UserSnowflake, toGitHubID githubID: String) async throws
    func unlinkGitHubID(discordID: UserSnowflake) async throws
    func getGitHubName(of discordID: UserSnowflake) async throws -> GitHubUserResponse
}
