@testable import Penny
@testable import Models
import DiscordModels
import Shared

package struct FakeUsersService: UsersService {
    
    package init() { }
    
    package func postCoin(with coinRequest: UserRequest.CoinEntryRequest) async throws -> CoinResponse {
        CoinResponse(
            sender: coinRequest.fromDiscordID,
            receiver: coinRequest.toDiscordID,
            newCoinCount: coinRequest.amount + .random(in: 0..<10_000)
        )
    }
    
    package func getCoinCount(of discordID: UserSnowflake) async throws -> Int {
        2591
    }

    package func linkGitHubID(discordID: UserSnowflake, toGitHubID githubID: String) async throws { }

    package func unlinkGitHubID(discordID: UserSnowflake) async throws { }

    package func getGitHubName(of discordID: UserSnowflake) async throws -> GitHubUserResponse {
        .userName("fake-username")
    }

    package func getUser(githubID: String) async throws -> DynamoDBUser? {
        var new = DynamoDBUser.createNew(forDiscordID: "1134810480968204288")
        new.githubID = githubID
        return new
    }
}
