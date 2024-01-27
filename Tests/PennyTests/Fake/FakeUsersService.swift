@testable import Penny
@testable import Models
import DiscordModels
import Shared

struct FakeUsersService: UsersService {
    
    init() { }
    
    func postCoin(with coinRequest: UserRequest.CoinEntryRequest) async throws -> CoinResponse {
        CoinResponse(
            sender: coinRequest.fromDiscordID,
            receiver: coinRequest.toDiscordID,
            newCoinCount: coinRequest.amount + .random(in: 0..<10_000)
        )
    }
    
    func getCoinCount(of discordID: UserSnowflake) async throws -> Int {
        2591
    }

    func linkGitHubID(discordID: UserSnowflake, toGitHubID githubID: String) async throws { }

    func unlinkGitHubID(discordID: UserSnowflake) async throws { }

    func getGitHubName(of discordID: UserSnowflake) async throws -> GitHubUserResponse {
        .userName("fake-username")
    }

    func getUser(githubID: String) async throws -> DynamoDBUser? {
        var new = DynamoDBUser.createNew(forDiscordID: "1134810480968204288")
        new.githubID = githubID
        return new
    }
}
