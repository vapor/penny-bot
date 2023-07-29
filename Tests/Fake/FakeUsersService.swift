@testable import Penny
@testable import Models
import DiscordModels
import SharedServices

public struct FakeUsersService: UsersService {
    
    public init() { }
    
    public func postCoin(with coinRequest: UserRequest.CoinEntryRequest) async throws -> CoinResponse {
        CoinResponse(
            sender: coinRequest.fromDiscordID,
            receiver: coinRequest.toDiscordID,
            newCoinCount: coinRequest.amount + .random(in: 0..<10_000)
        )
    }
    
    public func getCoinCount(of discordID: UserSnowflake) async throws -> Int {
        2591
    }

    public func getGitHubName(of discordID: UserSnowflake) async throws -> GitHubUserResponse {
        .userName("fake-username")
    }

    public func getUser(githubID: String) async throws -> DynamoDBUser? {
        var new = DynamoDBUser.createNew(forDiscordID: "1134810480968204288")
        new.githubID = githubID
        return new
    }

    public func linkGitHubID(discordID: UserSnowflake, toGitHubID githubID: String) async throws { }
}
