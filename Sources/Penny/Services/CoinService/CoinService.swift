import Models

protocol CoinService: Sendable {
    func postCoin(with coinRequest: CoinRequest.AddCoin) async throws -> CoinResponse
    func getCoinCount(of user: String) async throws -> Int
    func getGitHubID(of user: String) async throws -> GitHubUserResponse
}
